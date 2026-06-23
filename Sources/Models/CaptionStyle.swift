import SwiftUI

/// A burn-in caption preset. Sizes are expressed against a 1080px-tall
/// reference frame and scaled to the actual render size at export time.
struct CaptionStyle: Identifiable, Hashable {
    let id: String
    let name: String
    /// `nil` uses the bold system font.
    let fontName: String?
    /// Font size in points at the 1080px reference height.
    let referenceFontSize: CGFloat
    let textColor: Color
    let hasBackground: Bool
    let backgroundColor: Color
    let strokeColor: Color
    /// Stroke width in points at the reference height. `0` disables the stroke.
    let referenceStrokeWidth: CGFloat
    /// Vertical anchor of the caption: `0` = top, `1` = bottom.
    let verticalPosition: CGFloat
    let uppercase: Bool

    static let presets: [CaptionStyle] = [
        CaptionStyle(
            id: "clean",
            name: "Clean",
            fontName: nil,
            referenceFontSize: 64,
            textColor: .white,
            hasBackground: false,
            backgroundColor: .clear,
            strokeColor: .black,
            referenceStrokeWidth: 6,
            verticalPosition: 0.86,
            uppercase: false
        ),
        CaptionStyle(
            id: "bold",
            name: "Bold",
            fontName: nil,
            referenceFontSize: 76,
            textColor: .yellow,
            hasBackground: false,
            backgroundColor: .clear,
            strokeColor: .black,
            referenceStrokeWidth: 9,
            verticalPosition: 0.84,
            uppercase: true
        ),
        CaptionStyle(
            id: "boxed",
            name: "Boxed",
            fontName: nil,
            referenceFontSize: 60,
            textColor: .white,
            hasBackground: true,
            backgroundColor: Color.black.opacity(0.65),
            strokeColor: .clear,
            referenceStrokeWidth: 0,
            verticalPosition: 0.86,
            uppercase: false
        ),
        CaptionStyle(
            id: "top",
            name: "Top",
            fontName: nil,
            referenceFontSize: 60,
            textColor: .white,
            hasBackground: true,
            backgroundColor: Color.black.opacity(0.55),
            strokeColor: .clear,
            referenceStrokeWidth: 0,
            verticalPosition: 0.12,
            uppercase: false
        )
    ]
}
