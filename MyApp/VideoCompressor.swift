import Foundation
import Photos
import AVFoundation

struct VideoCompressor {
    static func compressAndReplace(asset: PHAsset) async -> Bool {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        // 1. Fetch the AVAsset safely before configuring the export
        guard let avAsset = await getAVAsset(for: asset, options: options) else { return false }
        
        // 2. Initialize the session in the same thread context (resolving the Sendable warning)
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPreset1280x720) else {
            return false
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        
        if #available(iOS 18.0, *) {
            do {
                try await exportSession.export(to: tempURL, as: .mp4)
                try await performReplacement(asset: asset, tempURL: tempURL)
                return true
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                return false
            }
        } else {
            // Fallback for iOS 17 and below
            exportSession.outputURL = tempURL
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true
            
            nonisolated(unsafe) let safeSession = exportSession
            
            let exportSuccess: Bool = await withCheckedContinuation { continuation in
                safeSession.exportAsynchronously {
                    continuation.resume(returning: safeSession.status == .completed)
                }
            }
            
            if exportSuccess {
                do {
                    try await performReplacement(asset: asset, tempURL: tempURL)
                    return true
                } catch {
                    try? FileManager.default.removeItem(at: tempURL)
                    return false
                }
            } else {
                try? FileManager.default.removeItem(at: tempURL)
                return false
            }
        }
    }
    
    // Async helper to prevent nesting
    private static func getAVAsset(for asset: PHAsset, options: PHVideoRequestOptions) async -> AVAsset? {
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                continuation.resume(returning: avAsset)
            }
        }
    }
    
    private static func performReplacement(asset: PHAsset, tempURL: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }
        try? FileManager.default.removeItem(at: tempURL)
    }
}
