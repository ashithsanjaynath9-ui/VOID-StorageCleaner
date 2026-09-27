import SwiftUI
import Photos
import CoreImage
import CoreImage.CIFilterBuiltins

struct MediaItem: Identifiable {
    let id = UUID()
    let asset: PHAsset
    var fileSize: Int64 = 0
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

@Observable
final class MediaScanner {
    var screenshots: [MediaItem] = []
    var largeVideos: [MediaItem] = []
    var blurryPhotos: [MediaItem] = []
    var isScanning = false
    
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
    
    func startScan() async {
        await MainActor.run { isScanning = true }
        
        await fetchScreenshots()
        await fetchLargeVideos()
        await fetchBlurryPhotos()
        
        await MainActor.run { isScanning = false }
    }
    
    private func fetchScreenshots() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoScreenshot.rawValue)
        let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var items: [MediaItem] = []
        
        results.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first {
                let size = resource.value(forKey: "fileSize") as? Int64 ?? 0
                items.append(MediaItem(asset: asset, fileSize: size))
            } else {
                items.append(MediaItem(asset: asset))
            }
        }
        
        await MainActor.run {
            self.screenshots = items
        }
    }
    
    private func fetchLargeVideos() async {
        let fetchOptions = PHFetchOptions()
        let results = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        
        var items: [MediaItem] = []
        
        results.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first {
                let size = resource.value(forKey: "fileSize") as? Int64 ?? 0
                
                if size > 20_000_000 {
                    items.append(MediaItem(asset: asset, fileSize: size))
                }
            }
        }
        
        items.sort { $0.fileSize > $1.fileSize }
        
        await MainActor.run {
            self.largeVideos = items
        }
    }
    
    private func fetchBlurryPhotos() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 250
        let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var items: [MediaItem] = []
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .fastFormat
        
        // Allows iCloud photos to be downloaded and scanned
        requestOptions.isNetworkAccessAllowed = true
        
        for i in 0..<results.count {
            let asset = results.object(at: i)
            
            if asset.mediaSubtypes.contains(.photoScreenshot) { continue }
            
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFit, options: requestOptions) { image, _ in
                guard let uiImage = image, let cgImage = uiImage.cgImage else { return }
                
                let ciImage = CIImage(cgImage: cgImage)
                
                let laplacian = CIFilter.edges()
                laplacian.inputImage = ciImage
                laplacian.intensity = 1.0
                
                guard let outputImage = laplacian.outputImage else { return }
                
                guard let varianceFilter = CIFilter(name: "CIAreaVariance") else { return }
                varianceFilter.setValue(outputImage, forKey: kCIInputImageKey)
                varianceFilter.setValue(CIVector(cgRect: outputImage.extent), forKey: kCIInputExtentKey)
                
                guard let varianceOutput = varianceFilter.outputImage else { return }
                
                var bitmap = [Float](repeating: 0, count: 4)
                self.ciContext.render(varianceOutput, toBitmap: &bitmap, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
                
                let variance = bitmap[0]
                
                // Cranked to 10 million to force the algorithm to catch photos for UI testing
                if variance < 10_000_000.0 {
                    let resources = PHAssetResource.assetResources(for: asset)
                    let size = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0
                    items.append(MediaItem(asset: asset, fileSize: size))
                }
            }
        }
        
        await MainActor.run {
            self.blurryPhotos = items
        }
    }
    
    func delete(items: [MediaItem]) async -> Bool {
        let assetsToDelete = items.map { $0.asset }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
            }
            
            await MainActor.run {
                let deletedIds = Set(items.map { $0.id })
                self.screenshots.removeAll { deletedIds.contains($0.id) }
                self.largeVideos.removeAll { deletedIds.contains($0.id) }
                self.blurryPhotos.removeAll { deletedIds.contains($0.id) }
            }
            return true
        } catch {
            print("Deletion failed or cancelled: \(error)")
            return false
        }
    }
}
