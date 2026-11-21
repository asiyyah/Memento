import SwiftUI

/// The three visual systems in the first slice.
enum CompositionStyle: String, CaseIterable, Identifiable, Hashable {
    case editorial
    case filmStrip
    case postcard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editorial: "Editorial"
        case .filmStrip: "Film Strip"
        case .postcard: "Postcard"
        }
    }
}

/// One arrangement of the picked photos. Small and cheap to copy: the layout is worked out from it on demand.
struct Composition: Equatable {
    let style: CompositionStyle
    /// Which arrangement of the style to use (a template, a strip shape, or a pile pattern).
    var variant: Int
    /// `order[slot]` is the index of the photo placed in that slot. Slot 0 is the most prominent.
    var order: [Int]
    /// Drives the small random touches, such as a print's tilt, so a layout redraws identically.
    var seed: UInt64
}

/// A finished layout, in design points, ready to draw at any size.
struct LayoutRecipe {
    var size: CGSize
    var elements: [LayoutElement]
    /// Outline colour for the selected photo.
    var selectionColor: Color = Color(red: 0.067, green: 0.067, blue: 0.067)
    /// Colour laid over photos that aren't selected.
    var dimColor: Color = .white
}

/// One thing to draw: a photo, a print, a piece of paper, film, or a line of text.
struct LayoutElement: Identifiable {
    enum Kind {
        /// A photo cropped to fill its frame.
        case photo
        /// A photo with a white border and a soft shadow.
        case print(border: CGFloat)
        /// The postcard's paper.
        case card
        /// The black body of a film strip.
        case filmBase
        /// One sprocket hole.
        case sprocket
        /// The editorial page with its hairline edge.
        case page
        case text(TextSpec)
    }

    let id: String
    var kind: Kind
    var frame: CGRect
    /// Degrees, clockwise.
    var rotation: Double = 0
    /// The photo drawn here, as an index into the session's photos.
    var photoIndex: Int? = nil
    /// The photo this element belongs to, for tapping and dimming (a caption belongs to its photo).
    var owner: Int? = nil

    var isText: Bool {
        if case .text = kind { return true }
        return false
    }
}

enum CanvasFont {
    case handwritten
    case serif
    case mono
    case sans
}

struct TextSpec {
    var string: String
    var font: CanvasFont
    var size: CGFloat
    var weight: Font.Weight = .regular
    var color: Color = Color(red: 0.067, green: 0.067, blue: 0.067)
    var tracking: CGFloat = 0
    var alignment: Alignment = .topLeading
}

/// A small, repeatable random number generator, so a seed always gives the same layout.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
