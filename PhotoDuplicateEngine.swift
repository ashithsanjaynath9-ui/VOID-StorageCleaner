import SwiftUI
import Photos

struct PhotoDuplicateGroup: Identifiable {
    let id = UUID()
    let mainAsset: PHAsset
    let duplicates: [PHAsset]
}

@Observable
final class PhotoDuplicateEngine {
    var duplicatePhotoGroups: [PhotoDuplicateGroup] = []
    var isScanning = false
    var totalSimilarPhotos = 0
    
    func scanForDuplicates() async {
        await MainActor.run { isScanning = true }
        
        let fetchOptions = PHFetchOptions()
        // Sort by creation date so similar moments are next to each other
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var assets: [PHAsset] = []
        allPhotos.enumerateObjects { asset, _, _ in
            // Exclude screenshots, since we handle those in the other engine
            if asset.mediaSubtypes != .photoScreenshot {
                assets.append(asset)
            }
        }
        
        var groups: [PhotoDuplicateGroup] = []
        var skipIndices: Set<Int> = []
        var totalFound = 0
        
        // Sliding window time-clustering algorithm
        for i in 0..<assets.count {
            if skipIndices.contains(i) { continue }
            
            var currentDuplicates: [PHAsset] = []
            let mainAsset = assets[i]
            
            // Only look at the next 15 photos to maintain high performance
            for j in (i + 1)..<min(i + 15, assets.count) {
                if skipIndices.contains(j) { continue }
                
                let compareAsset = assets[j]
                
                if let date1 = mainAsset.creationDate, let date2 = compareAsset.creationDate {
                    // If photos were taken within 3 seconds of each other, flag as similar
                    if abs(date1.timeIntervalSince(date2)) <= 3.0 {
                        currentDuplicates.append(compareAsset)
                        skipIndices.insert(j)
                        totalFound += 1
                    }
                }
            }
            
            if !currentDuplicates.isEmpty {
                groups.append(PhotoDuplicateGroup(mainAsset: mainAsset, duplicates: currentDuplicates))
            }
        }
        
        await MainActor.run {
            self.duplicatePhotoGroups = groups
            self.totalSimilarPhotos = totalFound
            self.isScanning = false
        }
    }
    
    func deleteDuplicates(in group: PhotoDuplicateGroup) async {
        let assetsToDelete = group.duplicates
        do {
            // This triggers the native iOS "Allow app to delete X photos?" prompt
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
            }
            
            // If the user taps "Allow", we update our dashboard counts
            await MainActor.run {
                if let index = duplicatePhotoGroups.firstIndex(where: { $0.id == group.id }) {
                    duplicatePhotoGroups.remove(at: index)
                    totalSimilarPhotos -= assetsToDelete.count
                }
            }
        } catch {
            print("Deletion cancelled or failed: \(error)")
        }
    }
}
