import SwiftUI
import Photos

/// Renders a layout to a full-size image, using the same drawing code as the screen.
enum KeepsakeRenderer {
    /// The longest side of the exported image, in points. Rendered at 2x, so 2400 pixels.
    static let longestSide: CGFloat = 1200

    static func render(recipe: LayoutRecipe, photos: [PickedPhoto]) -> UIImage? {
        let longest = max(recipe.size.width, recipe.size.height, 1)
        let canvas = CompositionCanvas(recipe: recipe, photos: photos, scale: longestSide / longest)
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 2
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

nonisolated enum SaveOutcome {
    case saved
    case denied
    case failed
}

/// Saves image data to the photo library, asking only for permission to add photos.
nonisolated enum PhotoLibrarySaver {
    @concurrent
    static func save(imageData: Data) async -> SaveOutcome {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .denied }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: imageData, options: nil)
            }
            return .saved
        } catch {
            return .failed
        }
    }
}
