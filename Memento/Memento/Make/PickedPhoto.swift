import SwiftUI
import PhotosUI
import ImageIO

/// One photo the user picked, already decoded at a size that suits the screen and export.
struct PickedPhoto: Identifiable {
    let id = UUID()
    let item: PhotosPickerItem
    let image: UIImage

    var aspectRatio: CGFloat {
        image.size.height > 0 ? image.size.width / image.size.height : 1
    }
}

enum ImageLoader {
    /// Decodes image data at a reduced size, so a full-resolution camera photo is never held in memory.
    static func downsampledImage(from data: Data, maxPixelSize: CGFloat = 2000) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
