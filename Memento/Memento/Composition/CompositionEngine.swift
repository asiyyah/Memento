import SwiftUI

/// Turns photos into layouts. Every layout is described as data (frames, rotations, text),
/// so a new arrangement is a new entry in a table, not a new screen.
enum CompositionEngine {

    // MARK: - Public

    /// The first arrangement for a style, chosen to suit the photos' shapes.
    static func initial(for style: CompositionStyle, photos: [PickedPhoto]) -> Composition {
        let identity = Array(photos.indices)
        let variant: Int
        switch style {
        case .editorial:
            variant = bestEditorialVariant(order: identity, photos: photos)
        case .filmStrip:
            variant = preferredFilmVariant(photos: photos)
        case .postcard:
            variant = 0
        }
        return Composition(style: style, variant: variant, order: identity, seed: 7)
    }

    /// Another valid arrangement in the same style: new pattern, new order, a different lead photo.
    static func shuffled(_ composition: Composition, photos: [PickedPhoto]) -> Composition {
        let count = photos.count
        guard count > 1 else { return composition }

        var rng = SystemRandomNumberGenerator()
        var next = composition

        let variants = variantCount(for: composition.style, photoCount: count)
        if variants > 1 {
            var variant = composition.variant
            while variant == composition.variant {
                variant = Int.random(in: 0..<variants, using: &rng)
            }
            next.variant = variant
        }

        if composition.style == .editorial {
            // Try a few orders and keep the one whose photos best suit their frames.
            let frames = editorialFrames(variant: next.variant, count: count)
            var best = shuffledOrder(from: composition.order, count: count, using: &rng)
            var bestCost = fitCost(frames: frames, order: best, photos: photos)
            for _ in 0..<5 {
                let candidate = shuffledOrder(from: composition.order, count: count, using: &rng)
                let cost = fitCost(frames: frames, order: candidate, photos: photos)
                if cost < bestCost {
                    best = candidate
                    bestCost = cost
                }
            }
            next.order = best
        } else {
            next.order = shuffledOrder(from: composition.order, count: count, using: &rng)
        }

        next.seed = UInt64.random(in: 1...UInt64.max, using: &rng)
        return next
    }

    /// The finished layout for an arrangement.
    static func layout(for composition: Composition, photos: [PickedPhoto]) -> LayoutRecipe {
        let order = validOrder(composition.order, count: photos.count)
        guard !order.isEmpty else {
            return LayoutRecipe(size: CGSize(width: 300, height: 400), elements: [])
        }
        switch composition.style {
        case .editorial:
            return editorialLayout(composition, order: order, photos: photos)
        case .filmStrip:
            return filmLayout(composition, order: order, photos: photos)
        case .postcard:
            return postcardLayout(composition, order: order, photos: photos)
        }
    }

    static func variantCount(for style: CompositionStyle, photoCount: Int) -> Int {
        switch style {
        case .editorial: editorialTemplates(count: photoCount).count
        case .filmStrip: filmOptions(count: photoCount).count
        case .postcard: pileSubsets(count: max(photoCount - 1, 0)).count
        }
    }

    // MARK: - Shared helpers

    private static func validOrder(_ order: [Int], count: Int) -> [Int] {
        if order.count == count, Set(order) == Set(0..<count) {
            return order
        }
        return Array(0..<count)
    }

    private static func shuffledOrder(from current: [Int], count: Int, using rng: inout SystemRandomNumberGenerator) -> [Int] {
        var order = Array(0..<count)
        for _ in 0..<8 {
            order.shuffle(using: &rng)
            if order.first != current.first { break }
        }
        return order
    }

    /// How badly the photos' shapes match their frames. Lower is better.
    private static func fitCost(frames: [CGRect], order: [Int], photos: [PickedPhoto]) -> Double {
        var cost = 0.0
        for (slot, frame) in frames.enumerated() where slot < order.count && photos.indices.contains(order[slot]) {
            let frameRatio = Double(frame.width / max(frame.height, 1))
            let photoRatio = Double(max(photos[order[slot]].aspectRatio, 0.01))
            cost += abs(log(frameRatio / photoRatio))
        }
        return cost
    }

    private static func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    private static func map(_ unit: CGRect, into box: CGRect) -> CGRect {
        CGRect(
            x: box.minX + unit.minX * box.width,
            y: box.minY + unit.minY * box.height,
            width: unit.width * box.width,
            height: unit.height * box.height
        )
    }

    /// Moves an element as if it were glued to a sheet turned about `pivot`.
    private static func rotated(_ element: LayoutElement, about pivot: CGPoint, degrees: Double) -> LayoutElement {
        var result = element
        let radians = degrees * .pi / 180
        let cosine = CGFloat(cos(radians))
        let sine = CGFloat(sin(radians))
        let dx = element.frame.midX - pivot.x
        let dy = element.frame.midY - pivot.y
        let center = CGPoint(x: pivot.x + dx * cosine - dy * sine, y: pivot.y + dx * sine + dy * cosine)
        result.frame = CGRect(
            x: center.x - element.frame.width / 2,
            y: center.y - element.frame.height / 2,
            width: element.frame.width,
            height: element.frame.height
        )
        result.rotation = element.rotation + degrees
        return result
    }

    // MARK: - Editorial

    /// A magazine page: one dominant photo, supporting photos, and a small block of type.
    /// Rectangles are fractions of the page's content area. The first photo rectangle is the hero.
    private struct EditorialTemplate {
        let photos: [CGRect]
        let copy: CGRect
    }

    private static let editorialCanvas = CGSize(width: 392, height: 482)
    private static let editorialPage = CGRect(x: 16, y: 16, width: 360, height: 450)
    private static let editorialContent = CGRect(x: 52, y: 58, width: 288, height: 366)

    private static let editorialTable: [Int: [EditorialTemplate]] = [
        1: [
            EditorialTemplate(photos: [rect(0, 0, 1, 0.86)], copy: rect(0, 0.9, 1, 0.1))
        ],
        2: [
            EditorialTemplate(photos: [rect(0, 0, 1, 0.56), rect(0, 0.6, 0.62, 0.4)], copy: rect(0.66, 0.6, 0.34, 0.22)),
            EditorialTemplate(photos: [rect(0, 0, 0.62, 0.78), rect(0.66, 0.44, 0.34, 0.34)], copy: rect(0.66, 0, 0.34, 0.22))
        ],
        3: [
            EditorialTemplate(photos: [rect(0, 0, 0.62, 0.68), rect(0.66, 0.36, 0.34, 0.32), rect(0, 0.72, 1, 0.28)],
                              copy: rect(0.66, 0, 0.34, 0.22)),
            EditorialTemplate(photos: [rect(0, 0, 1, 0.52), rect(0, 0.56, 0.48, 0.44), rect(0.52, 0.56, 0.48, 0.30)],
                              copy: rect(0.52, 0.89, 0.48, 0.11)),
            EditorialTemplate(photos: [rect(0.38, 0, 0.62, 0.64), rect(0, 0.32, 0.34, 0.32), rect(0, 0.68, 1, 0.32)],
                              copy: rect(0, 0, 0.34, 0.2))
        ],
        4: [
            EditorialTemplate(photos: [rect(0, 0, 0.64, 0.68), rect(0.68, 0.36, 0.32, 0.32), rect(0, 0.72, 0.64, 0.28),
                                       rect(0.68, 0.72, 0.32, 0.28)],
                              copy: rect(0.68, 0, 0.32, 0.2)),
            EditorialTemplate(photos: [rect(0, 0, 1, 0.5), rect(0, 0.54, 0.31, 0.46), rect(0.345, 0.54, 0.31, 0.46),
                                       rect(0.69, 0.54, 0.31, 0.30)],
                              copy: rect(0.69, 0.88, 0.31, 0.12)),
            EditorialTemplate(photos: [rect(0, 0.16, 0.58, 0.84), rect(0.62, 0, 0.38, 0.32), rect(0.62, 0.35, 0.38, 0.32),
                                       rect(0.62, 0.70, 0.38, 0.30)],
                              copy: rect(0, 0, 0.5, 0.12))
        ],
        5: [
            EditorialTemplate(photos: [rect(0, 0, 0.64, 0.62), rect(0.68, 0.30, 0.32, 0.32), rect(0, 0.66, 0.30, 0.34),
                                       rect(0.34, 0.66, 0.30, 0.34), rect(0.68, 0.66, 0.32, 0.34)],
                              copy: rect(0.68, 0, 0.32, 0.18)),
            EditorialTemplate(photos: [rect(0, 0, 1, 0.44), rect(0, 0.57, 0.31, 0.43), rect(0.345, 0.57, 0.31, 0.20),
                                       rect(0.345, 0.80, 0.31, 0.20), rect(0.69, 0.57, 0.31, 0.43)],
                              copy: rect(0, 0.47, 1, 0.07))
        ],
        6: [
            EditorialTemplate(photos: [rect(0, 0, 0.64, 0.52), rect(0.68, 0.20, 0.32, 0.32), rect(0, 0.56, 0.31, 0.21),
                                       rect(0.345, 0.56, 0.31, 0.21), rect(0.69, 0.56, 0.31, 0.21), rect(0, 0.81, 1, 0.19)],
                              copy: rect(0.68, 0, 0.32, 0.16)),
            EditorialTemplate(photos: [rect(0, 0.11, 0.64, 0.55), rect(0.68, 0.11, 0.32, 0.26), rect(0.68, 0.40, 0.32, 0.26),
                                       rect(0, 0.70, 0.31, 0.30), rect(0.345, 0.70, 0.31, 0.30), rect(0.69, 0.70, 0.31, 0.30)],
                              copy: rect(0, 0, 1, 0.08))
        ]
    ]

    private static func editorialTemplates(count: Int) -> [EditorialTemplate] {
        let clamped = min(max(count, 1), 6)
        return editorialTable[clamped] ?? []
    }

    private static func editorialFrames(variant: Int, count: Int) -> [CGRect] {
        let templates = editorialTemplates(count: count)
        guard !templates.isEmpty else { return [] }
        return templates[abs(variant) % templates.count].photos.map { map($0, into: editorialContent) }
    }

    private static func bestEditorialVariant(order: [Int], photos: [PickedPhoto]) -> Int {
        let count = editorialTemplates(count: photos.count).count
        guard count > 1 else { return 0 }
        var best = 0
        var bestCost = Double.infinity
        for variant in 0..<count {
            let cost = fitCost(frames: editorialFrames(variant: variant, count: photos.count), order: order, photos: photos)
            if cost < bestCost {
                best = variant
                bestCost = cost
            }
        }
        return best
    }

    private static func editorialLayout(_ composition: Composition, order: [Int], photos: [PickedPhoto]) -> LayoutRecipe {
        let templates = editorialTemplates(count: order.count)
        guard !templates.isEmpty else {
            return LayoutRecipe(size: editorialCanvas, elements: [])
        }
        let template = templates[abs(composition.variant) % templates.count]

        var elements = [LayoutElement(id: "page", kind: .page, frame: editorialPage)]

        for (slot, unit) in template.photos.enumerated() where slot < order.count {
            let index = order[slot]
            elements.append(LayoutElement(
                id: "photo-\(index)",
                kind: .photo,
                frame: map(unit, into: editorialContent),
                photoIndex: index,
                owner: index
            ))
        }

        let dates = photos.compactMap(\.capturedAt)
        let title = TextSpec(string: DateText.title(for: dates), font: .serif, size: 20)
        let subtitleText = dates.isEmpty ? "\(photos.count) PHOTOS" : DateText.range(dates)
        var subtitle = TextSpec(
            string: subtitleText,
            font: .mono,
            size: 8.5,
            color: Color(red: 0.333, green: 0.333, blue: 0.333),
            tracking: 0.8
        )

        let copy = map(template.copy, into: editorialContent)
        if copy.width > copy.height * 3 {
            // A wide, short strip: title on the left, dates on the right.
            var wideTitle = title
            wideTitle.alignment = .leading
            subtitle.alignment = .trailing
            elements.append(LayoutElement(
                id: "copy-title",
                kind: .text(wideTitle),
                frame: CGRect(x: copy.minX, y: copy.minY, width: copy.width * 0.6, height: copy.height)
            ))
            elements.append(LayoutElement(
                id: "copy-subtitle",
                kind: .text(subtitle),
                frame: CGRect(x: copy.minX + copy.width * 0.6, y: copy.minY, width: copy.width * 0.4, height: copy.height)
            ))
        } else {
            let titleHeight = min(copy.height * 0.7, 54)
            elements.append(LayoutElement(
                id: "copy-title",
                kind: .text(title),
                frame: CGRect(x: copy.minX, y: copy.minY, width: copy.width, height: titleHeight)
            ))
            elements.append(LayoutElement(
                id: "copy-subtitle",
                kind: .text(subtitle),
                frame: CGRect(x: copy.minX, y: copy.minY + titleHeight + 4, width: copy.width, height: 14)
            ))
        }

        return LayoutRecipe(size: editorialCanvas, elements: elements)
    }

    // MARK: - Film strip

    /// A roll of film: numbered frames with dates, sprocket holes down both edges.
    private enum FrameShape {
        case landscape
        case square
        case portrait

        var photoSize: CGSize {
            switch self {
            case .landscape: CGSize(width: 166, height: 112)
            case .square: CGSize(width: 136, height: 136)
            case .portrait: CGSize(width: 120, height: 160)
            }
        }
    }

    private struct FilmOption {
        let columns: Int
        let shape: FrameShape
    }

    private static func filmOptions(count: Int) -> [FilmOption] {
        switch count {
        case ...3:
            return [
                FilmOption(columns: 1, shape: .landscape),
                FilmOption(columns: 1, shape: .square),
                FilmOption(columns: 1, shape: .portrait)
            ]
        case 4:
            return [
                FilmOption(columns: 1, shape: .landscape),
                FilmOption(columns: 2, shape: .landscape),
                FilmOption(columns: 2, shape: .square),
                FilmOption(columns: 2, shape: .portrait)
            ]
        default:
            return [
                FilmOption(columns: 2, shape: .landscape),
                FilmOption(columns: 2, shape: .square),
                FilmOption(columns: 2, shape: .portrait)
            ]
        }
    }

    /// Picks frame shapes that match most of the photos.
    private static func preferredFilmVariant(photos: [PickedPhoto]) -> Int {
        let portraits = photos.filter { $0.aspectRatio < 0.9 }.count
        let landscapes = photos.filter { $0.aspectRatio > 1.1 }.count
        let wanted: FrameShape
        if portraits > landscapes {
            wanted = .portrait
        } else if landscapes > 0 {
            wanted = .landscape
        } else {
            wanted = .square
        }
        let options = filmOptions(count: photos.count)
        return options.firstIndex { $0.shape == wanted } ?? 0
    }

    private static func filmLayout(_ composition: Composition, order: [Int], photos: [PickedPhoto]) -> LayoutRecipe {
        let options = filmOptions(count: order.count)
        let option = options[abs(composition.variant) % options.count]
        let photoSize = option.shape.photoSize

        let margin: CGFloat = 20
        let stripGap: CGFloat = 20
        let edge: CGFloat = 28
        let padY: CGFloat = 16
        let frameGap: CGFloat = 10
        let captionGap: CGFloat = 5
        let captionHeight: CGFloat = 13
        let holeSize = CGSize(width: 10, height: 9)
        let holeGap: CGFloat = 11

        let frameHeight = photoSize.height + captionGap + captionHeight
        let stripWidth = photoSize.width + edge * 2
        let columns = max(1, min(option.columns, order.count))
        let perColumn = Int((Double(order.count) / Double(columns)).rounded(.up))

        var groups: [[Int]] = []
        var start = 0
        while start < order.count {
            let end = min(start + perColumn, order.count)
            groups.append(Array(start..<end))
            start = end
        }

        func stripHeight(_ frames: Int) -> CGFloat {
            padY * 2 + CGFloat(frames) * frameHeight + CGFloat(max(frames - 1, 0)) * frameGap
        }

        let tallest = groups.map { stripHeight($0.count) }.max() ?? 0
        let size = CGSize(
            width: margin * 2 + CGFloat(groups.count) * stripWidth + CGFloat(max(groups.count - 1, 0)) * stripGap,
            height: margin * 2 + tallest
        )

        let captionColor = Color(white: 0.82)
        var elements: [LayoutElement] = []

        for (column, slots) in groups.enumerated() {
            let height = stripHeight(slots.count)
            let strip = CGRect(
                x: margin + CGFloat(column) * (stripWidth + stripGap),
                y: margin,
                width: stripWidth,
                height: height
            )
            elements.append(LayoutElement(id: "strip-\(column)", kind: .filmBase, frame: strip))

            let usable = height - padY * 2
            let holes = max(Int((usable + holeGap) / (holeSize.height + holeGap)), 1)
            let used = CGFloat(holes) * holeSize.height + CGFloat(holes - 1) * holeGap
            let firstY = strip.minY + padY + (usable - used) / 2
            for hole in 0..<holes {
                let y = firstY + CGFloat(hole) * (holeSize.height + holeGap)
                elements.append(LayoutElement(
                    id: "hole-\(column)-left-\(hole)",
                    kind: .sprocket,
                    frame: CGRect(x: strip.minX + 9, y: y, width: holeSize.width, height: holeSize.height)
                ))
                elements.append(LayoutElement(
                    id: "hole-\(column)-right-\(hole)",
                    kind: .sprocket,
                    frame: CGRect(x: strip.maxX - 9 - holeSize.width, y: y, width: holeSize.width, height: holeSize.height)
                ))
            }

            for (row, slot) in slots.enumerated() {
                let index = order[slot]
                let photoFrame = CGRect(
                    x: strip.minX + edge,
                    y: strip.minY + padY + CGFloat(row) * (frameHeight + frameGap),
                    width: photoSize.width,
                    height: photoSize.height
                )
                elements.append(LayoutElement(
                    id: "photo-\(index)",
                    kind: .photo,
                    frame: photoFrame,
                    photoIndex: index,
                    owner: index
                ))

                let captionY = photoFrame.maxY + captionGap
                let number = TextSpec(
                    string: String(format: "%02dA", slot + 1),
                    font: .mono,
                    size: 8.5,
                    color: captionColor,
                    tracking: 0.5,
                    alignment: .leading
                )
                elements.append(LayoutElement(
                    id: "number-\(index)",
                    kind: .text(number),
                    frame: CGRect(x: photoFrame.minX, y: captionY, width: photoFrame.width * 0.4, height: captionHeight),
                    owner: index
                ))

                let stamp = TextSpec(
                    string: DateText.filmStamp(photos[index].capturedAt),
                    font: .mono,
                    size: 8.5,
                    color: captionColor,
                    tracking: 0.5,
                    alignment: .trailing
                )
                elements.append(LayoutElement(
                    id: "stamp-\(index)",
                    kind: .text(stamp),
                    frame: CGRect(x: photoFrame.minX + photoFrame.width * 0.35, y: captionY,
                                  width: photoFrame.width * 0.65, height: captionHeight),
                    owner: index
                ))
            }
        }

        return LayoutRecipe(size: size, elements: elements, selectionColor: .white, dimColor: .black)
    }

    // MARK: - Postcard

    /// A postcard lying on a loose pile of prints. Every photo is part of the keepsake.
    private struct PileSlot {
        let center: CGPoint
        let size: CGSize
        let rotation: Double
    }

    private static let postcardCanvas = CGSize(width: 400, height: 480)

    private static let pileSlots: [PileSlot] = [
        PileSlot(center: CGPoint(x: 105, y: 110), size: CGSize(width: 150, height: 150), rotation: -8),
        PileSlot(center: CGPoint(x: 305, y: 105), size: CGSize(width: 140, height: 180), rotation: 7),
        PileSlot(center: CGPoint(x: 175, y: 410), size: CGSize(width: 190, height: 116), rotation: -4),
        PileSlot(center: CGPoint(x: 322, y: 370), size: CGSize(width: 130, height: 160), rotation: 9),
        PileSlot(center: CGPoint(x: 80, y: 360), size: CGSize(width: 130, height: 130), rotation: -10)
    ]

    /// Which pile positions to use for a number of loose prints. Each list is one arrangement.
    private static func pileSubsets(count: Int) -> [[Int]] {
        switch count {
        case ...0: return [[]]
        case 1: return [[0], [1], [2]]
        case 2: return [[0, 1], [0, 2], [1, 4]]
        case 3: return [[0, 1, 2], [0, 1, 3], [1, 2, 4]]
        case 4: return [[0, 1, 2, 3], [0, 1, 2, 4], [0, 1, 3, 4]]
        default: return [[0, 1, 2, 3, 4]]
        }
    }

    private static func postcardLayout(_ composition: Composition, order: [Int], photos: [PickedPhoto]) -> LayoutRecipe {
        var rng = SeededGenerator(seed: composition.seed)
        var elements: [LayoutElement] = []

        // The loose prints underneath, sized to each photo's shape.
        let pile = Array(order.dropFirst())
        let subsets = pileSubsets(count: pile.count)
        let subset = subsets[abs(composition.variant) % subsets.count]
        for (position, index) in pile.enumerated() where position < subset.count {
            let slot = pileSlots[subset[position]]
            let ratio = min(max(photos[index].aspectRatio, 0.78), 1.3)
            let area = slot.size.width * slot.size.height
            let width = (area * ratio).squareRoot()
            let height = (area / ratio).squareRoot()
            let tilt = Double.random(in: -3...3, using: &rng)
            elements.append(LayoutElement(
                id: "photo-\(index)",
                kind: .print(border: 6),
                frame: CGRect(x: slot.center.x - width / 2, y: slot.center.y - height / 2, width: width, height: height),
                rotation: slot.rotation + tilt,
                photoIndex: index,
                owner: index
            ))
        }

        // The postcard on top.
        let cardIndex = order[0]
        let cardPhoto = photos[cardIndex]
        let photoSize: CGSize
        if cardPhoto.aspectRatio > 1.1 {
            photoSize = CGSize(width: 268, height: 200)
        } else if cardPhoto.aspectRatio < 0.9 {
            photoSize = CGSize(width: 214, height: 268)
        } else {
            photoSize = CGSize(width: 236, height: 236)
        }
        let padding: CGFloat = 16
        let captionArea: CGFloat = 44
        let cardSize = CGSize(width: photoSize.width + padding * 2, height: photoSize.height + padding + captionArea)
        let center = CGPoint(x: 200, y: 236)
        let card = CGRect(x: center.x - cardSize.width / 2, y: center.y - cardSize.height / 2,
                          width: cardSize.width, height: cardSize.height)
        let photoFrame = CGRect(x: card.minX + padding, y: card.minY + padding,
                                width: photoSize.width, height: photoSize.height)

        let dateString = DateText.card(cardPhoto.capturedAt)
        let date = TextSpec(
            string: dateString.isEmpty ? "Lately" : dateString,
            font: .handwritten,
            size: 24,
            alignment: .leading
        )
        let yearString = DateText.year(cardPhoto.capturedAt)
        let detail = TextSpec(
            string: yearString.isEmpty ? "MEMENTO" : yearString,
            font: .sans,
            size: 10,
            weight: .medium,
            color: Color(red: 0.333, green: 0.333, blue: 0.333),
            tracking: 1.5,
            alignment: .trailing
        )

        let cardElements = [
            LayoutElement(id: "card", kind: .card, frame: card, owner: cardIndex),
            LayoutElement(id: "photo-\(cardIndex)", kind: .photo, frame: photoFrame, photoIndex: cardIndex, owner: cardIndex),
            LayoutElement(
                id: "card-date",
                kind: .text(date),
                frame: CGRect(x: photoFrame.minX, y: photoFrame.maxY + 6, width: photoFrame.width * 0.7, height: 34),
                owner: cardIndex
            ),
            LayoutElement(
                id: "card-detail",
                kind: .text(detail),
                frame: CGRect(x: photoFrame.minX + photoFrame.width * 0.5, y: photoFrame.maxY + 14,
                              width: photoFrame.width * 0.5, height: 18),
                owner: cardIndex
            )
        ]

        let tilts: [Double] = [-3, -2, 2, 3]
        let cardTilt: Double = tilts.randomElement(using: &rng) ?? -2
        for element in cardElements {
            elements.append(rotated(element, about: center, degrees: cardTilt))
        }

        return LayoutRecipe(size: postcardCanvas, elements: elements)
    }
}
