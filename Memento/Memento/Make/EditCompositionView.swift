import SwiftUI
import PhotosUI

/// Step 3 of Make: shuffle the arrangement, or tap a photo to replace it.
struct EditCompositionView: View {
    let session: MakeSession
    let style: CompositionStyle
    var onDone: () -> Void

    @State private var selectedPhoto: Int?
    @State private var replacementItem: PhotosPickerItem?
    @State private var isReplacing = false
    @State private var replaceFailed = false
    @State private var shuffleCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let recipe = CompositionEngine.layout(for: session.composition(for: style), photos: session.photos)

        VStack(spacing: 24) {
            FittedCompositionCanvas(
                recipe: recipe,
                photos: session.photos,
                selectedPhoto: selectedPhoto,
                onTapPhoto: { index in select(index) },
                onTapBackground: { deselect() }
            )
            .frame(maxHeight: .infinity)

            controls
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Theme.paper
                .contentShape(Rectangle())
                .onTapGesture { deselect() }
        }
        .navigationTitle(style.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done", action: onDone)
                    .fontWeight(.semibold)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: shuffleCount)
        .sensoryFeedback(.selection, trigger: selectedPhoto)
        .onChange(of: replacementItem) { _, item in
            guard let item, let index = selectedPhoto else { return }
            replacementItem = nil
            replace(at: index, with: item)
        }
        .alert("That photo can't be used", isPresented: $replaceFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("It may already be in this keepsake, or still downloading from iCloud. Try another photo.")
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 12) {
            if let selectedPhoto {
                PhotosPicker(
                    selection: $replacementItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    if isReplacing {
                        ProgressView()
                    } else {
                        Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .outline))
                .disabled(isReplacing)
                .accessibilityHint("Choose a different photo for photo \(selectedPhoto + 1)")

                Text("Tap anywhere else to deselect")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                Button(action: shuffle) {
                    Label("Shuffle", systemImage: "shuffle")
                }
                .buttonStyle(PillButtonStyle(kind: .outline))
                .accessibilityHint("Rearranges the photos in this style")

                Text("Tap a photo to replace it")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .frame(height: 96)
    }

    // MARK: Actions

    private func shuffle() {
        let next = CompositionEngine.shuffled(session.composition(for: style), photos: session.photos)
        withAnimation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.18)) {
            session.setComposition(next)
        }
        shuffleCount += 1
    }

    private func select(_ index: Int) {
        withAnimation(.snappy(duration: 0.2)) {
            selectedPhoto = selectedPhoto == index ? nil : index
        }
    }

    private func deselect() {
        guard selectedPhoto != nil else { return }
        withAnimation(.snappy(duration: 0.2)) {
            selectedPhoto = nil
        }
    }

    private func replace(at index: Int, with item: PhotosPickerItem) {
        isReplacing = true
        Task {
            let replaced = await session.replacePhoto(at: index, with: item)
            isReplacing = false
            if !replaced {
                replaceFailed = true
            }
        }
    }
}
