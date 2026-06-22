import Foundation
import Speech

enum TranscriptionError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case onDeviceUnavailable
    case failed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "音声認識の利用が許可されていません。設定から許可してください。"
        case .recognizerUnavailable:
            return "この言語の音声認識は利用できません。"
        case .onDeviceUnavailable:
            return "オンデバイス音声認識がこの端末/言語では利用できません。"
        case .failed(let error):
            return "字幕の生成に失敗しました：\(error.localizedDescription)"
        }
    }
}

/// A single recognized word with its timing, used as input to the grouping
/// step. Kept framework-agnostic so the grouping logic can be unit tested
/// without the Speech framework.
struct TimedWord: Equatable {
    let text: String
    let start: TimeInterval
    let duration: TimeInterval
}

/// On-device speech-to-text. Reads the audio track of a video file directly
/// and returns caption-sized, timed segments.
@MainActor
final class TranscriptionService {

    func transcribe(url: URL, locale: Locale = .current) async throws -> [TranscriptSegment] {
        guard await Self.requestAuthorization() == .authorized else {
            throw TranscriptionError.notAuthorized
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.onDeviceUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !didResume {
                        didResume = true
                        continuation.resume(throwing: TranscriptionError.failed(error))
                    }
                    return
                }
                guard let result, result.isFinal else { return }
                let words = result.bestTranscription.segments.map {
                    TimedWord(text: $0.substring, start: $0.timestamp, duration: $0.duration)
                }
                if !didResume {
                    didResume = true
                    continuation.resume(returning: Self.group(words: words))
                }
            }
        }
    }

    private static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Groups recognized words into short, on-screen-friendly caption lines.
    /// A new line is started after `maxWords` words or when there is a silent
    /// gap longer than `maxGap` seconds between words.
    nonisolated static func group(words: [TimedWord], maxWords: Int = 7, maxGap: TimeInterval = 0.8) -> [TranscriptSegment] {
        guard !words.isEmpty else { return [] }

        var segments: [TranscriptSegment] = []
        var current: [TimedWord] = []

        func flush() {
            guard let first = current.first, let last = current.last else { return }
            let text = current.map(\.text).joined(separator: " ")
            let duration = (last.start + last.duration) - first.start
            segments.append(
                TranscriptSegment(text: text, start: first.start, duration: max(duration, 0.4))
            )
            current.removeAll()
        }

        for word in words {
            if let previous = current.last {
                let gap = word.start - (previous.start + previous.duration)
                if current.count >= maxWords || gap > maxGap {
                    flush()
                }
            }
            current.append(word)
        }
        flush()
        return segments
    }
}
