import SwiftUI
import PhotosUI

/// Step 1 of Make: pick 3 to 6 photos, review them, then continue.
struct PickPhotosView: View {
    @Bindable var session: MakeSession
    var onContinue: () -> Void

    private let tileHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            if session.photos.isEmpty && !session.isLoading {
                emptyState
            } else {
                selection
            }
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.paper)
        .onChange(of: session.pickerItems) {
            Task { await session.syncPhotos() }
        }
        .sensoryFeedback(.selection, trigger: session.photos.count)
        .alert("Some photos couldn't be loaded", isPresented: failedLoadBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("They may still be downloading from iCloud. Try picking them again in a moment.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("Make")
                .font(Theme.Fonts.screenTitle)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if !session.photos.isEmpty {
                Text("\(session.photos.count) of \(MakeSession.maximumPhotos) photos")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            BlankPile()
                .frame(width: 260, height: 210)
                .accessibilityHidden(true)
            Text("Make something")
                .font(Theme.Fonts.handwritten(32))
                .foregroundStyle(Theme.ink)
            Text("Pick 3 to 6 photos to turn into a keepsake.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
            photoPicker {
                Text("Choose photos")
            }
            .buttonStyle(PillButtonStyle())
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Selected photos

    private var selection: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], spacing: 16) {
                        ForEach(Array(session.photos.enumerated()), id: \.element.id) { index, photo in
                            tile(photo, number: index + 1)
                        }
                        if session.photos.count < MakeSession.maximumPhotos {
                            addTile
                        }
                    }
                    if session.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading photos…")
                        }
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.secondaryInk)
                    }
                    Text(helperText)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.secondaryInk)
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()

            Button("Continue", action: onContinue)
                .buttonStyle(PillButtonStyle())
                .disabled(!session.canContinue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.paper)
        }
    }

    private var helperText: String {
        if session.photos.count < MakeSession.minimumPhotos {
            return "Pick at least \(MakeSession.minimumPhotos) photos to continue."
        }
        return "Photos stay in the order you picked them."
    }

    private func tile(_ photo: PickedPhoto, number: Int) -> some View {
        PrintView(image: photo.image)
            .frame(height: tileHeight)
            .accessibilityLabel("Photo \(number)")
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.snappy) { session.remove(photo) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 28, height: 28)
                        .background(Color.white, in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Remove photo \(number)")
            }
    }

    private var addTile: some View {
        photoPicker {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                Text("Add more")
                    .font(Theme.Fonts.captionStrong)
            }
            .foregroundStyle(Theme.secondaryInk)
            .frame(maxWidth: .infinity)
            .frame(height: tileHeight)
            .overlay {
                Rectangle().strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func photoPicker<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        PhotosPicker(
            selection: $session.pickerItems,
            maxSelectionCount: MakeSession.maximumPhotos,
            selectionBehavior: .ordered,
            matching: .images,
            photoLibrary: .shared(),
            label: label
        )
    }

    private var failedLoadBinding: Binding<Bool> {
        Binding(
            get: { session.failedLoadCount > 0 },
            set: { if !$0 { session.failedLoadCount = 0 } }
        )
    }
}

/// Three blank prints, loosely stacked, for the empty state.
private struct BlankPile: View {
    var body: some View {
        ZStack {
            PrintView(image: nil)
                .frame(width: 150, height: 120)
                .rotationEffect(.degrees(-8))
                .offset(x: -40, y: 0)
            PrintView(image: nil)
                .frame(width: 150, height: 120)
                .rotationEffect(.degrees(7))
                .offset(x: 44, y: -18)
            PrintView(image: nil)
                .frame(width: 164, height: 134)
                .rotationEffect(.degrees(-2))
                .offset(x: 0, y: 16)
        }
    }
}

#Preview {
    PickPhotosView(session: MakeSession(), onContinue: {})
}
