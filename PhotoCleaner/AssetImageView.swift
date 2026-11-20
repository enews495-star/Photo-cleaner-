import Photos
import SwiftUI
import UIKit

/// Loads and displays a photo from the library, fitted to the available space.
struct AssetImageView: View {
    let asset: PHAsset
    var contentMode: ContentMode = .fit

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    ProgressView()
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .task(id: asset.localIdentifier) {
                await load(size: geo.size)
            }
        }
    }

    private func load(size: CGSize) async {
        image = nil
        let scale = displayScale
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic   // fast low-res first, then full quality
        options.isNetworkAccessAllowed = true   // download from iCloud if needed
        options.resizeMode = .fast

        let manager = PHImageManager.default()
        let stream = AsyncStream<UIImage> { continuation in
            let requestID = manager.requestImage(
                for: asset,
                targetSize: target,
                contentMode: contentMode == .fit ? .aspectFit : .aspectFill,
                options: options
            ) { result, info in
                if let result { continuation.yield(result) }
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !degraded { continuation.finish() }
            }
            continuation.onTermination = { _ in
                manager.cancelImageRequest(requestID)
            }
        }

        for await next in stream {
            image = next
        }
    }
}
