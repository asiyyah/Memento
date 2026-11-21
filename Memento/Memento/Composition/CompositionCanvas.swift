import SwiftUI

/// Draws a layout at an exact scale. The editor, the carousel and the exported image all use this,
/// so what you save is exactly what you saw.
struct CompositionCanvas: View {
    let recipe: LayoutRecipe
    let photos: [PickedPhoto]
    /// Points on screen per design point.
    let scale: CGFloat
    var selectedPhoto: Int? = nil
    var onTapPhoto: ((Int) -> Void)? = nil
    var onTapBackground: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .contentShape(Rectangle())
                .onTapGesture { onTapBackground?() }
                .accessibilityHidden(true)

            ForEach(Array(recipe.elements.enumerated()), id: \.element.id) { position, element in
                elementView(element)
                    .zIndex(Double(position))
            }
        }
        .frame(width: recipe.size.width * scale, height: recipe.size.height * scale)
    }

    // MARK: Elements

    private func elementView(_ element: LayoutElement) -> some View {
        let frame = element.frame
        let dimmed = isDimmed(element)
        return elementContent(element)
            .frame(width: frame.width * scale, height: frame.height * scale)
            .overlay {
                if dimmed && !element.isText {
                    recipe.dimColor.opacity(0.6)
                }
            }
            .opacity(dimmed && element.isText ? 0.35 : 1)
            .contentShape(Rectangle())
            .onTapGesture { handleTap(on: element) }
            .accessibilityHidden(element.photoIndex == nil)
            .accessibilityLabel(element.photoIndex.map { "Photo \($0 + 1)" } ?? "")
            .accessibilityAddTraits(element.photoIndex == selectedPhoto && selectedPhoto != nil ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { handleTap(on: element) }
            .rotationEffect(.degrees(element.rotation))
            .position(x: frame.midX * scale, y: frame.midY * scale)
    }

    @ViewBuilder
    private func elementContent(_ element: LayoutElement) -> some View {
        switch element.kind {
        case .photo:
            photoImage(element.photoIndex)
                .overlay { selectionRing(element) }

        case .print(let border):
            photoImage(element.photoIndex)
                .padding(border * scale)
                .background(Color.white)
                .overlay { selectionRing(element) }
                .shadow(color: .black.opacity(0.14), radius: 5 * scale, y: 2 * scale)

        case .card:
            Color.white
                .shadow(color: .black.opacity(0.16), radius: 14 * scale, y: 8 * scale)

        case .filmBase:
            Color(red: 0.08, green: 0.08, blue: 0.08)

        case .sprocket:
            RoundedRectangle(cornerRadius: 1.5 * scale)
                .fill(Color(white: 0.95))

        case .page:
            Rectangle()
                .fill(Color.white)
                .overlay {
                    Rectangle().strokeBorder(Color(red: 0.87, green: 0.87, blue: 0.85), lineWidth: max(1, 0.8 * scale))
                }

        case .text(let spec):
            Text(spec.string)
                .font(font(for: spec))
                .tracking(spec.tracking * scale)
                .foregroundStyle(spec.color)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(spec.alignment == .trailing ? .trailing : .leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: spec.alignment)
        }
    }

    @ViewBuilder
    private func photoImage(_ index: Int?) -> some View {
        if let index, photos.indices.contains(index) {
            // The clear shape takes exactly the frame's size; the photo fills it and is cropped to it.
            Color.clear
                .overlay {
                    Image(uiImage: photos[index].image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        } else {
            Theme.blankPrint
        }
    }

    @ViewBuilder
    private func selectionRing(_ element: LayoutElement) -> some View {
        if let selectedPhoto, element.photoIndex == selectedPhoto {
            Rectangle().strokeBorder(recipe.selectionColor, lineWidth: 3)
        }
    }

    // MARK: Helpers

    private func isDimmed(_ element: LayoutElement) -> Bool {
        guard let selectedPhoto, let owner = element.owner else { return false }
        return owner != selectedPhoto
    }

    private func handleTap(on element: LayoutElement) {
        if let owner = element.owner {
            onTapPhoto?(owner)
        } else {
            onTapBackground?()
        }
    }

    private func font(for spec: TextSpec) -> Font {
        let size = spec.size * scale
        switch spec.font {
        case .handwritten:
            return .custom("BradleyHandITCTT-Bold", fixedSize: size)
        case .serif:
            return .system(size: size, weight: spec.weight, design: .serif)
        case .mono:
            return .system(size: size, weight: spec.weight, design: .monospaced)
        case .sans:
            return .system(size: size, weight: spec.weight)
        }
    }
}

/// Draws a layout as large as fits the space it's given, centred.
struct FittedCompositionCanvas: View {
    let recipe: LayoutRecipe
    let photos: [PickedPhoto]
    var selectedPhoto: Int? = nil
    var onTapPhoto: ((Int) -> Void)? = nil
    var onTapBackground: (() -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / max(recipe.size.width, 1),
                proxy.size.height / max(recipe.size.height, 1)
            )
            CompositionCanvas(
                recipe: recipe,
                photos: photos,
                scale: max(scale, 0.01),
                selectedPhoto: selectedPhoto,
                onTapPhoto: onTapPhoto,
                onTapBackground: onTapBackground
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
