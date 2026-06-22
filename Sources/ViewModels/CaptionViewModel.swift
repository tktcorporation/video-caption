import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class CaptionViewModel: ObservableObject {
    @Published var statusMessage = ""
    @Published var isWorking = false
    @Published var hasVideo = false
    @Published var segments: [TranscriptSegment] = []
    @Published var selectedStyleID: String = CaptionStyle.presets[0].id
    @Published var outputURL: URL?
    @Published var errorMessage: String?

    var selectedStyle: CaptionStyle {
        CaptionStyle.presets.first { $0.id == selectedStyleID } ?? CaptionStyle.presets[0]
    }

    private var videoURL: URL?
    private let transcriber = TranscriptionService()
    private let burner = CaptionBurner()

    func handlePicked(_ item: PhotosPickerItem) async {
        reset()
        isWorking = true
        statusMessage = "動画を読み込み中…"
        do {
            guard let movie = try await item.loadTransferable(type: MovieFile.self) else {
                throw AppError("動画を読み込めませんでした。")
            }
            videoURL = movie.url
            hasVideo = true

            statusMessage = "字幕を生成中…（オンデバイス）"
            let result = try await transcriber.transcribe(url: movie.url)
            segments = result
            statusMessage = result.isEmpty
                ? "音声を認識できませんでした。"
                : "字幕を生成しました（\(result.count)行）"
        } catch {
            errorMessage = message(for: error)
            statusMessage = ""
        }
        isWorking = false
    }

    func burn() async {
        guard let videoURL, !segments.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        outputURL = nil
        statusMessage = "字幕を焼き込み中…"
        do {
            let output = FileManager.default.temporaryDirectory
                .appendingPathComponent("caption-\(UUID().uuidString)")
                .appendingPathExtension("mp4")
            outputURL = try await burner.burn(
                videoURL: videoURL,
                segments: segments,
                style: selectedStyle,
                outputURL: output
            )
            statusMessage = "完成しました。"
        } catch {
            errorMessage = message(for: error)
            statusMessage = ""
        }
        isWorking = false
    }

    private func reset() {
        segments = []
        outputURL = nil
        errorMessage = nil
        hasVideo = false
        videoURL = nil
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

private struct AppError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
