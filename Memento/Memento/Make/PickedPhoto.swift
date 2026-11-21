import SwiftUI
import PhotosUI
import ImageIO

/// One photo the user picked, already decoded at a size that suits the screen and export.
struct PickedPhoto: Identifiable {
    let id = UUID()
    let item: PhotosPickerItem
    let image: UIImage
    var capturedAt: Date? = nil

    var aspectRatio: CGFloat {
        image.size.height > 0 ? image.size.width / image.size.height : 1
    }
}

/// A decoded image plus the date it was taken, when the file records one.
struct LoadedImage {
    let image: UIImage
    let capturedAt: Date?
}

enum ImageLoader {
    /// Decodes image data at a reduced size, so a full-resolution camera photo is never held in memory.
    static func load(_ data: Data, maxPixelSize: CGFloat = 2000) -> LoadedImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return LoadedImage(image: UIImage(cgImage: cgImage), capturedAt: captureDate(from: source))
    }

    private static func captureDate(from source: CGImageSource) -> Date? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let raw = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
            ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String)
        guard let raw else { return nil }
        return exifFormatter.date(from: raw)
    }

    private static let exifFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
}
