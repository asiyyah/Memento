import SwiftUI
import PhotosUI
import Observation

/// State for one trip through the Make flow: the photos picked and the arrangement chosen for each style.
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

    /// The current arrangement for each style, kept so going back and forth doesn't lose a shuffle.
    private(set) var compositions: [CompositionStyle: Composition] = [:]
    /// The photos the stored arrangements were made for.
    private var compositionBasis: [UUID] = []

    var canContinue: Bool {
        photos.count >= Self.minimumPhotos && !isLoading
    }

    // MARK: Picking

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
            if let loaded = await Self.load(item) {
                updated.append(PickedPhoto(item: item, image: loaded.image, capturedAt: loaded.capturedAt))
            } else {
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

    /// Swaps one photo for another, keeping its place in every arrangement.
    /// Returns false when the new photo is already in the set or can't be loaded.
    func replacePhoto(at index: Int, with item: PhotosPickerItem) async -> Bool {
        guard photos.indices.contains(index), !pickerItems.contains(item) else { return false }
        guard let loaded = await Self.load(item), photos.indices.contains(index) else { return false }

        let old = photos[index]
        let new = PickedPhoto(item: item, image: loaded.image, capturedAt: loaded.capturedAt)
        photos[index] = new
        if compositionBasis.indices.contains(index) {
            compositionBasis[index] = new.id
        }
        if let pickerIndex = pickerItems.firstIndex(of: old.item) {
            pickerItems[pickerIndex] = item
        }
        return true
    }

    /// Clears everything, ready for a new keepsake.
    func reset() {
        pickerItems = []
        photos = []
        compositions = [:]
        compositionBasis = []
        failedLoadCount = 0
        isLoading = false
    }

    // MARK: Compositions

    /// The arrangement to show for a style. Never changes state, so it's safe to call while drawing.
    func composition(for style: CompositionStyle) -> Composition {
        if let stored = compositions[style], stored.order.count == photos.count {
            return stored
        }
        return CompositionEngine.initial(for: style, photos: photos)
    }

    /// Makes fresh arrangements when the picked photos have changed since last time.
    func prepareCompositions() {
        let ids = photos.map(\.id)
        guard ids != compositionBasis || compositions.count != CompositionStyle.allCases.count else { return }
        compositionBasis = ids
        var fresh: [CompositionStyle: Composition] = [:]
        for style in CompositionStyle.allCases {
            fresh[style] = CompositionEngine.initial(for: style, photos: photos)
        }
        compositions = fresh
    }

    func setComposition(_ composition: Composition) {
        compositions[composition.style] = composition
    }

    // MARK: Loading

    private static func load(_ item: PhotosPickerItem) async -> LoadedImage? {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return nil }
            return ImageLoader.load(data)
        } catch {
            return nil
        }
    }
}
