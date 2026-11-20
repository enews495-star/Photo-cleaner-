import Foundation
import Observation
import Photos

/// What the user decided for a single photo.
enum SwipeAction {
    case keep
    case delete
}

/// Owns photo-library access, the queue of photos to review, and the
/// list of photos the user has marked for deletion.
@MainActor
@Observable
final class PhotoLibrary {
    struct Decision {
        let asset: PHAsset
        let action: SwipeAction
    }

    private(set) var authorization: PHAuthorizationStatus
    private(set) var assets: [PHAsset] = []
    private(set) var currentIndex = 0
    private(set) var history: [Decision] = []
    private(set) var isLoading = false
    private(set) var totalInLibrary = 0

    /// IDs of photos the user already swiped "keep" on in a previous session,
    /// so they are not shown again.
    private var keptIDs: Set<String>
    private static let keptIDsKey = "keptAssetIDs"

    init() {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        keptIDs = Set(UserDefaults.standard.stringArray(forKey: Self.keptIDsKey) ?? [])
        if hasAccess { loadAssets() }
    }

    // MARK: - Derived state

    var hasAccess: Bool {
        authorization == .authorized || authorization == .limited
    }

    var currentAsset: PHAsset? {
        assets.indices.contains(currentIndex) ? assets[currentIndex] : nil
    }

    var nextAsset: PHAsset? {
        assets.indices.contains(currentIndex + 1) ? assets[currentIndex + 1] : nil
    }

    var remainingCount: Int { max(assets.count - currentIndex, 0) }

    var markedForDeletion: [PHAsset] {
        history.filter { $0.action == .delete }.map(\.asset)
    }

    var keptThisSessionCount: Int {
        history.filter { $0.action == .keep }.count
    }

    var canUndo: Bool { !history.isEmpty }

    // MARK: - Access

    func requestAccess() async {
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if hasAccess { loadAssets() }
    }

    func loadAssets() {
        isLoading = true
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)

        let alreadyKept = keptIDs
        var list: [PHAsset] = []
        list.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            if !alreadyKept.contains(asset.localIdentifier) {
                list.append(asset)
            }
        }

        totalInLibrary = result.count
        assets = list
        currentIndex = 0
        history = []
        isLoading = false
    }

    // MARK: - Swiping

    func decide(_ action: SwipeAction) {
        guard let asset = currentAsset else { return }
        history.append(Decision(asset: asset, action: action))
        if action == .keep {
            keptIDs.insert(asset.localIdentifier)
            saveKeptIDs()
        }
        currentIndex += 1
    }

    func undo() {
        guard let last = history.popLast() else { return }
        if last.action == .keep {
            keptIDs.remove(last.asset.localIdentifier)
            saveKeptIDs()
        }
        currentIndex = max(currentIndex - 1, 0)
    }

    /// Un-marks a photo from the deletion list (from the review screen).
    func unmark(_ asset: PHAsset) {
        guard let i = history.lastIndex(where: {
            $0.action == .delete && $0.asset.localIdentifier == asset.localIdentifier
        }) else { return }
        history[i] = Decision(asset: asset, action: .keep)
        keptIDs.insert(asset.localIdentifier)
        saveKeptIDs()
    }

    /// Deletes every photo marked for deletion in one batch. iOS shows its own
    /// confirmation prompt; deleted photos go to "Recently Deleted" for 30 days.
    /// Returns true if the photos were deleted, false if the user cancelled.
    @discardableResult
    func deleteMarked() async throws -> Bool {
        let ids = markedForDeletion.map(\.localIdentifier)
        guard !ids.isEmpty else { return false }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let toDelete = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                PHAssetChangeRequest.deleteAssets(toDelete)
            }
        } catch let error as NSError
            where error.domain == PHPhotosErrorDomain && error.code == PHPhotosError.Code.userCancelled.rawValue {
            return false
        }

        // Drop deleted photos from the queue and history.
        let deleted = Set(ids)
        let reviewedBeforeCurrent = assets.prefix(currentIndex).filter { deleted.contains($0.localIdentifier) }.count
        assets.removeAll { deleted.contains($0.localIdentifier) }
        currentIndex -= reviewedBeforeCurrent
        history.removeAll { deleted.contains($0.asset.localIdentifier) }
        totalInLibrary -= ids.count
        return true
    }

    /// Forget every "keep" decision and show the whole library again.
    func startOver() {
        keptIDs.removeAll()
        saveKeptIDs()
        loadAssets()
    }

    private func saveKeptIDs() {
        UserDefaults.standard.set(Array(keptIDs), forKey: Self.keptIDsKey)
    }
}
