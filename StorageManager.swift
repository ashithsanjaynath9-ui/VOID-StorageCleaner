import Foundation

struct StorageInfo {
    let totalBytes: Int64
    let freeBytes: Int64
    
    var usedBytes: Int64 {
        totalBytes - freeBytes
    }
    
    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }
    
    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}

final class StorageManager {
    static func getDeviceStorage() -> StorageInfo {
        let fileManager = FileManager.default
        do {
            let values = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            let total = (values[.systemSize] as? NSNumber)?.int64Value ?? 0
            let free = (values[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            return StorageInfo(totalBytes: total, freeBytes: free)
        } catch {
            return StorageInfo(totalBytes: 0, freeBytes: 0)
        }
    }
}
