import Foundation

/// A timed line of recognized text to be rendered as a caption.
struct TranscriptSegment: Identifiable, Equatable {
    let id: UUID
    var text: String
    /// Seconds from the start of the video.
    var start: TimeInterval
    /// How long the caption stays on screen, in seconds.
    var duration: TimeInterval

    init(id: UUID = UUID(), text: String, start: TimeInterval, duration: TimeInterval) {
        self.id = id
        self.text = text
        self.start = start
        self.duration = duration
    }

    var end: TimeInterval { start + duration }
}
