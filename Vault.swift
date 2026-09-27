import SwiftUI
import LocalAuthentication
import Photos

@Observable
final class VaultEngine {
    var isUnlocked = false
    var vaultImages: [UIImage] = []
    
    private let vaultURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("AppVault")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    func lock() {
        isUnlocked = false
        vaultImages.removeAll()
    }
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Access your private vault") { success, _ in
                Task { @MainActor in
                    if success {
                        self.isUnlocked = true
                        self.loadImages()
                    }
                }
            }
        } else {
            // Fallback for simulators without Face ID
            Task { @MainActor in
                self.isUnlocked = true
                self.loadImages()
            }
        }
    }
    
    private func loadImages() {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: vaultURL, includingPropertiesForKeys: nil) else { return }
        var loaded: [UIImage] = []
        for url in urls {
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                loaded.append(img)
            }
        }
        self.vaultImages = loaded
    }
    
    func secureItem(asset: PHAsset) async -> Bool {
        return await withCheckedContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            
            manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                guard let image = image, let data = image.jpegData(compressionQuality: 0.9) else {
                    continuation.resume(returning: false)
                    return
                }
                
                let fileURL = self.vaultURL.appendingPathComponent(UUID().uuidString + ".jpg")
                do {
                    try data.write(to: fileURL)
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                    }) { success, _ in
                        continuation.resume(returning: success)
                    }
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

struct VaultView: View {
    @State private var engine = VaultEngine()
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        ZStack {
            ThemeBackground()
            
            if !engine.isUnlocked {
                VStack(spacing: 32) {
                    Image(systemName: "faceid")
                        .font(.system(size: 80, weight: .thin))
                        .foregroundStyle(.purple)
                        .padding()
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 160, height: 160)
                        )
                        .shadow(color: .purple.opacity(0.4), radius: 20, x: 0, y: 10)
                        
                    Text("PRIVATE VAULT")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(2)
                    
                    Button(action: { 
                        Haptics.impact(.medium)
                        engine.authenticate() 
                    }) {
                        HStack {
                            Image(systemName: "lock.open.fill")
                            Text("AUTHENTICATE")
                        }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.purple)
                            .cornerRadius(20)
                            .padding(.horizontal, 40)
                    }
                    .antigravityButton()
                }
            } else {
                if engine.vaultImages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.gray.opacity(0.5))
                        Text("VAULT IS EMPTY")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                            .tracking(1)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(0..<engine.vaultImages.count, id: \.self) { index in
                                Image(uiImage: engine.vaultImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipped()
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Private Vault")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.1, green: 0.1, blue: 0.3), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onDisappear {
            engine.lock()
        }
    }
}
