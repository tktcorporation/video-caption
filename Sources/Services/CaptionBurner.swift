import AVFoundation
import QuartzCore
import SwiftUI
import UIKit

enum CaptionBurnerError: LocalizedError {
    case noVideoTrack
    case exportSessionCreationFailed
    case exportFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "動画トラックが見つかりませんでした。"
        case .exportSessionCreationFailed:
            return "書き出しセッションを作成できませんでした。"
        case .exportFailed(let error):
            return "書き出しに失敗しました：\(error?.localizedDescription ?? "不明なエラー")"
        }
    }
}

/// Burns timed captions into a video using AVFoundation + Core Animation and
/// exports the result. Entirely on-device.
struct CaptionBurner {

    func burn(
        videoURL: URL,
        segments: [TranscriptSegment],
        style: CaptionStyle,
        outputURL: URL
    ) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw CaptionBurnerError.noVideoTrack
        }
        let naturalSize = try await sourceVideoTrack.load(.naturalSize)
        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        let duration = try await asset.load(.duration)
        let nominalFrameRate = try await sourceVideoTrack.load(.nominalFrameRate)

        // Upright render size after applying the track's orientation transform.
        let transformed = naturalSize.applying(preferredTransform)
        let renderSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))

        // Build a composition carrying the original video (and audio if present).
        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw CaptionBurnerError.noVideoTrack
        }
        let fullRange = CMTimeRange(start: .zero, duration: duration)
        try compVideoTrack.insertTimeRange(fullRange, of: sourceVideoTrack, at: .zero)

        if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compAudioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            // Use the audio track's own valid range rather than assuming it
            // spans `asset.duration` (trimmed/offset assets otherwise throw),
            // and insert it at its original start time so leading silence or a
            // delayed audio offset stays in sync with the video and captions.
            let audioRange = try await sourceAudioTrack.load(.timeRange)
            let available = duration - audioRange.start
            let insertDuration = max(.zero, CMTimeMinimum(audioRange.duration, available))
            if insertDuration > .zero {
                let sourceRange = CMTimeRange(start: audioRange.start, duration: insertDuration)
                do {
                    try compAudioTrack.insertTimeRange(sourceRange, of: sourceAudioTrack, at: audioRange.start)
                } catch {
                    // Keep the captioned video usable, but don't leave a
                    // dangling empty audio track in the export.
                    composition.removeTrack(compAudioTrack)
                }
            } else {
                composition.removeTrack(compAudioTrack)
            }
        }

        // Video composition: render upright and overlay the caption layers.
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        let fps = nominalFrameRate > 0 ? CMTimeScale(nominalFrameRate.rounded()) : 30
        videoComposition.frameDuration = CMTime(value: 1, timescale: max(fps, 1))

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = fullRange
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(Self.overlayLayer(segments: segments, style: style, renderSize: renderSize))

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        // Export.
        try? FileManager.default.removeItem(at: outputURL)
        guard let export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw CaptionBurnerError.exportSessionCreationFailed
        }
        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.videoComposition = videoComposition
        export.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { continuation in
            export.exportAsynchronously {
                continuation.resume()
            }
        }

        guard export.status == .completed else {
            throw CaptionBurnerError.exportFailed(export.error)
        }
        return outputURL
    }

    // MARK: - Overlay rendering

    /// Builds the caption overlay. Note that the Core Animation tool renders in
    /// a bottom-left origin coordinate system.
    private static func overlayLayer(
        segments: [TranscriptSegment],
        style: CaptionStyle,
        renderSize: CGSize
    ) -> CALayer {
        let overlay = CALayer()
        overlay.frame = CGRect(origin: .zero, size: renderSize)

        let scale = renderSize.height / 1080.0
        let fontSize = style.referenceFontSize * scale
        let strokeWidth = style.referenceStrokeWidth * scale
        let font = resolvedFont(name: style.fontName, size: fontSize)

        let horizontalMargin = renderSize.width * 0.05
        let boxWidth = renderSize.width - horizontalMargin * 2
        let boxHeight = fontSize * 3.4

        // `verticalPosition` is measured from the top; convert to bottom-left origin.
        let centerFromTop = style.verticalPosition * renderSize.height
        let originY = (renderSize.height - centerFromTop) - boxHeight / 2

        for segment in segments {
            let textLayer = CATextLayer()
            textLayer.string = attributedString(for: segment.text, style: style, font: font, strokeWidth: strokeWidth)
            textLayer.isWrapped = true
            textLayer.alignmentMode = .center
            textLayer.contentsScale = 1
            textLayer.frame = CGRect(x: horizontalMargin, y: originY, width: boxWidth, height: boxHeight)
            textLayer.opacity = 0

            if style.hasBackground {
                textLayer.backgroundColor = UIColor(style.backgroundColor).cgColor
                textLayer.cornerRadius = 10 * scale
                textLayer.masksToBounds = true
            }

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0.0, 1.0, 1.0, 0.0]
            fade.keyTimes = [0.0, 0.08, 0.92, 1.0]
            fade.beginTime = segment.start == 0 ? AVCoreAnimationBeginTimeAtZero : segment.start
            fade.duration = max(segment.duration, 0.4)
            fade.isRemovedOnCompletion = false
            fade.fillMode = .forwards
            textLayer.add(fade, forKey: "captionFade")

            overlay.addSublayer(textLayer)
        }
        return overlay
    }

    private static func resolvedFont(name: String?, size: CGFloat) -> UIFont {
        if let name, let custom = UIFont(name: name, size: size) {
            return custom
        }
        return UIFont.systemFont(ofSize: size, weight: .heavy)
    }

    private static func attributedString(
        for text: String,
        style: CaptionStyle,
        font: UIFont,
        strokeWidth: CGFloat
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(style.textColor),
            .paragraphStyle: paragraph
        ]
        if strokeWidth > 0 {
            attributes[.strokeColor] = UIColor(style.strokeColor)
            // Negative width fills the glyphs and strokes them.
            attributes[.strokeWidth] = -strokeWidth
        }

        let displayText = style.uppercase ? text.uppercased() : text
        return NSAttributedString(string: displayText, attributes: attributes)
    }
}
