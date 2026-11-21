import SwiftUI

/// Step 4 of Make: the finished keepsake on its own, with Save and Share.
struct PreviewKeepsakeView: View {
    let session: MakeSession
    let style: CompositionStyle
    var onKeepEditing: () -> Void
    var onMakeAnother: () -> Void

    @State private var exportedImage: UIImage?
    @State private var isSaving = false
    @State private var outcome: SaveOutcome?
    @Environment(\.openURL) private var openURL

    var body: some View {
        let recipe = CompositionEngine.layout(for: session.composition(for: style), photos: session.photos)

        VStack(spacing: 24) {
            FittedCompositionCanvas(recipe: recipe, photos: session.photos)
                .allowsHitTesting(false)
                .frame(maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Your \(style.title) keepsake with \(session.photos.count) photos")

            VStack(spacing: 4) {
                Text("Keep this one?")
                    .font(Theme.Fonts.handwritten(36))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("\(style.title) · \(session.photos.count) photos")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }

            VStack(spacing: 4) {
                HStack(spacing: 12) {
                    Button(action: save) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save")
                        }
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(exportedImage == nil || isSaving)

                    if let exportedImage {
                        let image = Image(uiImage: exportedImage)
                        ShareLink(item: image, preview: SharePreview("Memento keepsake", image: image)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PillButtonStyle(kind: .outline))
                    }
                }

                Button("Keep editing", action: onKeepEditing)
                    .font(Theme.Fonts.captionStrong)
                    .underline()
                    .foregroundStyle(Theme.ink)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
        .navigationTitle("Keep this one?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .onAppear(perform: render)
        .alert(alertTitle, isPresented: alertBinding) {
            switch outcome {
            case .saved:
                Button("Done", action: onMakeAnother)
                Button("Stay here", role: .cancel) {}
            case .denied:
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button("Not now", role: .cancel) {}
            default:
                Button("OK", role: .cancel) {}
            }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: Actions

    private func render() {
        let recipe = CompositionEngine.layout(for: session.composition(for: style), photos: session.photos)
        exportedImage = KeepsakeRenderer.render(recipe: recipe, photos: session.photos)
    }

    private func save() {
        guard let data = exportedImage?.jpegData(compressionQuality: 0.92) else {
            outcome = .failed
            return
        }
        isSaving = true
        Task {
            let result = await PhotoLibrarySaver.save(imageData: data)
            isSaving = false
            outcome = result
        }
    }

    // MARK: Alert

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { outcome != nil },
            set: { if !$0 { outcome = nil } }
        )
    }

    private var alertTitle: String {
        switch outcome {
        case .saved: "Saved to Photos"
        case .denied: "Memento can't add to Photos"
        case .failed: "The keepsake wasn't saved"
        case nil: ""
        }
    }

    private var alertMessage: String {
        switch outcome {
        case .saved: "Your keepsake is in your photo library. Done starts a new one; Stay here lets you share this one first."
        case .denied: "Allow Memento to add photos in Settings, under Privacy & Security › Photos."
        case .failed: "Try again, or use Share to send it somewhere instead."
        case nil: ""
        }
    }
}
