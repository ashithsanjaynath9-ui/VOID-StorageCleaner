import SwiftUI
import Photos

struct DuplicateReviewView: View {
    @Bindable var photoEngine: PhotoDuplicateEngine
    
    var body: some View {
        ZStack {
            ThemeBackground()
            
            ScrollView {
                VStack(spacing: 40) {
                    if photoEngine.duplicatePhotoGroups.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.green)
                            Text("NO DUPLICATES FOUND")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                                .tracking(1)
                        }
                        .padding(.top, 100)
                    } else {
                        ForEach(photoEngine.duplicatePhotoGroups) { group in
                            DuplicateGroupRow(group: group, photoEngine: photoEngine)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.1, green: 0.1, blue: 0.3), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

// Extracting this row fixes the "reasonable time" compiler error
struct DuplicateGroupRow: View {
    let group: PhotoDuplicateGroup
    let photoEngine: PhotoDuplicateEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                Text("SIMILAR MOMENT")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Original Photo
                    AssetImageView(asset: group.mainAsset)
                        .frame(width: 160, height: 160)
                        .cornerRadius(12)
                        .overlay(
                            Text("ORIGINAL")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(6)
                                .foregroundColor(.white)
                                .padding(8),
                            alignment: .bottomLeading
                        )
                    
                    // Duplicates
                    ForEach(group.duplicates, id: \.localIdentifier) { dup in
                        AssetImageView(asset: dup)
                            .frame(width: 160, height: 160)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Button(action: {
                Task {
                    await photoEngine.deleteDuplicates(in: group)
                    Haptics.impact(.medium)
                }
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("DELETE \(group.duplicates.count) DUPLICATE(S)")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .glassCard()
            }
            .antigravityButton()
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
    }
}

struct AssetImageView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    // This environment variable fixes the yellow UIScreen deprecation warnings
    @Environment(\.displayScale) var displayScale
    
    var body: some View {
        GeometryReader { geo in
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(white: 0.15)
                }
            }
            .onAppear {
                fetchImage(size: geo.size, scale: displayScale)
            }
        }
    }
    
    private func fetchImage(size: CGSize, scale: CGFloat) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { result, _ in
            if let result = result {
                self.image = result
            }
        }
    }
}
