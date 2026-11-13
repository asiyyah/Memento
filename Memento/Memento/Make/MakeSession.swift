import SwiftUI
import PhotosUI
import Observation

/// State for one trip through the Make flow: the photos picked so far.
@Observable
final class MakeSession {
    static let minimumPhotos = 3
    static let maximumPhotos = 6

    /// What the system photo picker currently has selected.
    var pickerItems: [PhotosPickerItem] = []
    /// The loaded photos, in the order they were picked.
    private(set) var photos: [PickedPhoto] = []
    private(set) var isLoading = false
    /// How many photos failed to load in the last pick. Drives the alert.
    var failedLoadCount = 0

    var canContinue: Bool {
        photos.count >= Self.minimumPhotos && !isLoading
    }

    /// Brings `photos` in line with the picker selection, loading only the new ones.
    func syncPhotos() async {
        let items = pickerItems
        isLoading = true

        var updated: [PickedPhoto] = []
        var failures = 0
        for item in items {
            if let existing = photos.first(where: { $0.item == item }) {
                updated.append(existing)
                continue
            }
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = ImageLoader.downsampledImage(from: data) {
                    updated.append(PickedPhoto(item: item, image: image))
                } else {
                    failures += 1
                }
            } catch {
                failures += 1
            }
        }

        // A newer selection arrived while loading; let that run finish instead.
        guard items == pickerItems else { return }

        photos = updated
        isLoading = false
        if failures > 0 {
            pickerItems = updated.map(\.item)
            failedLoadCount = failures
        }
    }

    func remove(_ photo: PickedPhoto) {
        photos.removeAll { $0.id == photo.id }
        pickerItems.removeAll { $0 == photo.item }
    }
}
