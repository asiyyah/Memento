import SwiftUI

/// Step 2 of Make: swipe through the picked photos in each style, tap one to start editing.
struct ChooseCompositionView: View {
    let session: MakeSession

    /// The style currently showing in the carousel.
    @State private var current: CompositionStyle = .editorial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Make something with these")
                    .font(Theme.Fonts.handwritten(32))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("\(CompositionStyle.allCases.count) compositions from your \(session.photos.count) photos")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .padding(.horizontal, Theme.screenPadding)

            TabView(selection: $current) {
                ForEach(CompositionStyle.allCases) { style in
                    NavigationLink(value: MakeStep.edit(style)) {
                        card(for: style)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Theme.screenPadding)
                    .tag(style)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            stylePicker

            Text("Swipe or pick a style, then tap it to start")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
        .sensoryFeedback(.selection, trigger: current)
        .navigationTitle("Compositions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Color.clear.frame(width: 1, height: 1)
            }
        }
    }

    /// The three style names. The current one is bold and underlined, so it doesn't rely on colour.
    private var stylePicker: some View {
        HStack(spacing: 8) {
            ForEach(CompositionStyle.allCases) { style in
                let isCurrent = current == style
                Button {
                    withAnimation(reduceMotion ? nil : .snappy) {
                        current = style
                    }
                } label: {
                    Text(style.title)
                        .font(.system(size: 15, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Theme.ink : Theme.secondaryInk)
                        .underline(isCurrent)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
                .accessibilityHint("Shows the \(style.title) composition")
            }
        }
    }

    private func card(for style: CompositionStyle) -> some View {
        let recipe = CompositionEngine.layout(for: session.composition(for: style), photos: session.photos)
        return FittedCompositionCanvas(recipe: recipe, photos: session.photos)
            .allowsHitTesting(false)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(style.title) composition")
            .accessibilityHint("Opens it for editing")
            .accessibilityAddTraits(.isButton)
    }
}
