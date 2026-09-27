import SwiftUI
import Photos

struct SwipeReviewView: View {
    @Bindable var photoEngine: PhotoDuplicateEngine
    @State private var currentIndex = 0
    @State private var itemsToDelete: [PHAsset] = []
    @Environment(\.dismiss) var dismiss

    var swipableAssets: [PHAsset] {
        photoEngine.duplicatePhotoGroups.flatMap { $0.duplicates }
    }

    var body: some View {
        ZStack {
            ThemeBackground()

            VStack {
                if currentIndex < swipableAssets.count {
                    let currentAsset = swipableAssets[currentIndex]
                    
                    HStack {
                        Image(systemName: "hand.point.left.fill")
                            .foregroundStyle(.red)
                        Text("SWIPE TO TRASH OR KEEP")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                            .tracking(1)
                        Image(systemName: "hand.point.right.fill")
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 40)

                    Spacer()

                    SwipeCard(asset: currentAsset) { swipedLeft in
                        if swipedLeft {
                            Haptics.impact(.medium)
                            itemsToDelete.append(currentAsset)
                            
                            if itemsToDelete.count >= 10 {
                                let batch = itemsToDelete
                                itemsToDelete.removeAll()
                                processDeletion(for: batch)
                            }
                        } else {
                            Haptics.impact(.light)
                        }
                        currentIndex += 1
                    }
                    .id(currentAsset.localIdentifier)
                    
                    Spacer()
                } else {
                    VStack(spacing: 32) {
                        Image(systemName: "sparkles.square.filled.on.square")
                            .font(.system(size: 80))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.orange, .yellow)
                        
                        Text("REVIEW COMPLETE")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(2)
                        
                        Text("You have \(itemsToDelete.count) remaining item(s) to remove.")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.gray)

                        if !itemsToDelete.isEmpty {
                            Button(action: {
                                let leftovers = itemsToDelete
                                itemsToDelete.removeAll()
                                processDeletion(for: leftovers)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("CONFIRM DELETION")
                                }
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .tracking(1)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color.red)
                                .cornerRadius(20)
                            }
                            .antigravityButton()
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                        } else {
                            Button(action: {
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "house.fill")
                                    Text("RETURN TO DASHBOARD")
                                }
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .tracking(1)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .glassCard()
                            }
                            .antigravityButton()
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                        }
                    }
                }
            }
        }
        .navigationTitle("Swipe Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.1, green: 0.1, blue: 0.3), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    private func processDeletion(for assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        
        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets(assets as NSArray)
                }
                
                await MainActor.run {
                    Haptics.impact(.medium)
                    let deletedIds = Set(assets.map { $0.localIdentifier })
                    var updatedGroups: [PhotoDuplicateGroup] = []
                    
                    for group in photoEngine.duplicatePhotoGroups {
                        let remaining = group.duplicates.filter { !deletedIds.contains($0.localIdentifier) }
                        if !remaining.isEmpty {
                            updatedGroups.append(PhotoDuplicateGroup(mainAsset: group.mainAsset, duplicates: remaining))
                        }
                    }
                    
                    photoEngine.duplicatePhotoGroups = updatedGroups
                    photoEngine.totalSimilarPhotos -= assets.count
                }
            } catch {
                print("Deletion cancelled by user")
            }
        }
    }
}

struct SwipeCard: View {
    let asset: PHAsset
    let onSwipe: (Bool) -> Void
    
    @State private var offset: CGSize = .zero
    @State private var image: UIImage?
    @Environment(\.displayScale) var displayScale

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width - 40, height: geo.size.height)
                        .cornerRadius(20)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: geo.size.width - 40, height: geo.size.height)
                }
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: geo.size.width - 40, height: geo.size.height)
                
                if offset.width < 0 {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("TRASH")
                    }
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                    .rotationEffect(.degrees(-15))
                    .opacity(Double(-offset.width / 100))
                    .position(x: geo.size.width - 80, y: 80)
                    .shadow(radius: 5)
                } else if offset.width > 0 {
                    HStack {
                        Image(systemName: "archivebox.fill")
                        Text("KEEP")
                    }
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(15))
                    .opacity(Double(offset.width / 100))
                    .position(x: 100, y: 80)
                    .shadow(radius: 5)
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .offset(x: offset.width, y: offset.height * 0.2)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        offset = gesture.translation
                    }
                    .onEnded { _ in
                        if offset.width < -100 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                offset = CGSize(width: -800, height: offset.height)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onSwipe(true)
                            }
                        } else if offset.width > 100 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                offset = CGSize(width: 800, height: offset.height)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onSwipe(false)
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                offset = .zero
                            }
                        }
                    }
            )
            .onAppear {
                fetchImage(size: geo.size, scale: displayScale)
            }
        }
        .frame(height: 550)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
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
