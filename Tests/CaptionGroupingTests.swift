import XCTest
@testable import VideoCaption

final class CaptionGroupingTests: XCTestCase {

    func testEmptyInputProducesNoSegments() {
        XCTAssertTrue(TranscriptionService.group(words: []).isEmpty)
    }

    func testSplitsOnMaxWords() {
        let words = (0..<10).map { index in
            TimedWord(text: "w\(index)", start: Double(index) * 0.5, duration: 0.4)
        }
        let segments = TranscriptionService.group(words: words, maxWords: 4, maxGap: 100)
        XCTAssertEqual(segments.count, 3) // 4 + 4 + 2
        XCTAssertEqual(segments[0].text, "w0 w1 w2 w3")
        XCTAssertEqual(segments[1].text, "w4 w5 w6 w7")
        XCTAssertEqual(segments[2].text, "w8 w9")
    }

    func testSplitsOnSilentGap() {
        let words = [
            TimedWord(text: "hello", start: 0.0, duration: 0.4),
            TimedWord(text: "there", start: 0.5, duration: 0.4),
            // Long pause before the next word.
            TimedWord(text: "world", start: 3.0, duration: 0.4)
        ]
        let segments = TranscriptionService.group(words: words, maxWords: 10, maxGap: 0.8)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].text, "hello there")
        XCTAssertEqual(segments[1].text, "world")
    }

    func testSegmentTimingSpansFirstToLastWord() {
        let words = [
            TimedWord(text: "a", start: 1.0, duration: 0.5),
            TimedWord(text: "b", start: 2.0, duration: 0.5)
        ]
        let segments = TranscriptionService.group(words: words, maxWords: 10, maxGap: 100)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].start, 1.0, accuracy: 0.0001)
        XCTAssertEqual(segments[0].end, 2.5, accuracy: 0.0001)
    }
}

final class CaptionStyleTests: XCTestCase {

    func testPresetsAreNonEmptyAndUnique() {
        let presets = CaptionStyle.presets
        XCTAssertGreaterThanOrEqual(presets.count, 4)
        let ids = Set(presets.map(\.id))
        XCTAssertEqual(ids.count, presets.count, "Preset ids must be unique")
    }
}
