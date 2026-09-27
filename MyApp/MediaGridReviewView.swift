import SwiftUI
import Photos

enum MediaType {
    case screenshots, largeVideos, blurryPhotos
}

struct MediaGridReviewView: View {
    let title: String
    @Bindable var scanner: MediaScanner
    let mediaType: MediaType
    
    @State private var selectedItems: Set<UUID> = []
    @State private var showSummary = false
    @State private var lastFreedSpace = ""
    @State private var lastDeletedCount = 0
    @State private var isProcessing = false
    
    var items: [MediaItem] {
        switch mediaType {
        case .screenshots: return scanner.screenshots
        case .largeVideos: return scanner.largeVideos
        case .blurryPhotos: return scanner.blurryPhotos
        }
    }
    
    var totalSelectedSize: String {
        let selected = items.filter { selectedItems.contains($0.id) }
        let bytes = selected.reduce(0) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        ZStack {
            ThemeBackground()
            
            if items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("NO ITEMS FOUND")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(1)
                }
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(items) { item in
                                MediaCell(item: item, isSelected: selectedItems.contains(item.id))
                                    .onTapGesture {
                                        if !isProcessing {
                                            Haptics.impact(.light)
                                            if selectedItems.contains(item.id) {
                                                selectedItems.remove(item.id)
                                            } else {
                                                selectedItems.insert(item.id)
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    
                    if !selectedItems.isEmpty {
                        VStack {
                            if mediaType == .largeVideos {
                                HStack(spacing: 16) {
                                    Button(action: { processDeletion() }) {
                                        HStack {
                                            Image(systemName: "trash.fill")
                                            Text(isProcessing ? "..." : "DELETE")
                                        }
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .tracking(1)
                                            .foregroundColor(.red)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 18)
                                            .glassCard()
                                    }
                                    .antigravityButton()
                                    .disabled(isProcessing)
                                    
                                    Button(action: { processCompression() }) {
                                        HStack {
                                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                            Text(isProcessing ? "WORKING..." : "COMPRESS")
                                        }
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .tracking(1)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 18)
                                            .background(Color.blue)
                                            .cornerRadius(20)
                                    }
                                    .antigravityButton()
                                    .disabled(isProcessing)
                                }
                            } else {
                                HStack(spacing: 16) {
                                    Button(action: { processDeletion() }) {
                                        HStack {
                                            Image(systemName: "trash.fill")
                                            Text(isProcessing ? "..." : "DELETE")
                                        }
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .tracking(1)
                                            .foregroundColor(.red)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 18)
                                            .glassCard()
                                    }
                                    .antigravityButton()
                                    .disabled(isProcessing)
                                    
                                    Button(action: { processVault() }) {
                                        HStack {
                                            Image(systemName: "lock.shield.fill")
                                            Text(isProcessing ? "WORKING..." : "SECURE")
                                        }
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .tracking(1)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 18)
                                            .background(Color.purple)
                                            .cornerRadius(20)
                                    }
                                    .antigravityButton()
                                    .disabled(isProcessing)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .background(.ultraThinMaterial)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.1, green: 0.1, blue: 0.3), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fullScreenCover(isPresented: $showSummary) {
            SuccessSummaryView(freedSpace: lastFreedSpace, itemCount: lastDeletedCount)
        }
    }
    
    private func processDeletion() {
        let itemsToDelete = items.filter { selectedItems.contains($0.id) }
        let spaceToFree = totalSelectedSize
        let countToFree = itemsToDelete.count
        
        Task {
            await MainActor.run { isProcessing = true }
            let success = await scanner.delete(items: itemsToDelete)
            await MainActor.run {
                isProcessing = false
                if success {
                    Haptics.impact(.medium)
                    lastFreedSpace = spaceToFree
                    lastDeletedCount = countToFree
                    selectedItems.removeAll()
                    showSummary = true
                }
            }
        }
    }
    
    private func processCompression() {
        let itemsToCompress = items.filter { selectedItems.contains($0.id) }
        Task {
            await MainActor.run { isProcessing = true }
            var successCount = 0
            for item in itemsToCompress {
                let success = await VideoCompressor.compressAndReplace(asset: item.asset)
                if success { successCount += 1 }
            }
            await MainActor.run {
                if successCount > 0 {
                    let deletedIds = Set(itemsToCompress.map { $0.id })
                    Haptics.impact(.medium)
                    scanner.largeVideos.removeAll { deletedIds.contains($0.id) }
                    selectedItems.removeAll()
                }
                isProcessing = false
            }
        }
    }
    
    private func processVault() {
        let itemsToSecure = items.filter { selectedItems.contains($0.id) }
        Task {
            await MainActor.run { isProcessing = true }
            let vault = VaultEngine()
            var successCount = 0
            for item in itemsToSecure {
                let success = await vault.secureItem(asset: item.asset)
                if success { successCount += 1 }
            }
            await MainActor.run {
                if successCount > 0 {
                    let deletedIds = Set(itemsToSecure.map { $0.id })
                    Haptics.impact(.medium)
                    scanner.screenshots.removeAll { deletedIds.contains($0.id) }
                    scanner.blurryPhotos.removeAll { deletedIds.contains($0.id) }
                    selectedItems.removeAll()
                }
                isProcessing = false
            }
        }
    }
}

struct MediaCell: View {
    let item: MediaItem
    let isSelected: Bool
    @State private var image: UIImage?
    @Environment(\.displayScale) var displayScale
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(isSelected ? 0.6 : 1.0)
                } else {
                    Color(white: 0.15)
                }
                
                if isSelected {
                    ZStack {
                        Color.blue.opacity(0.4)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 28, weight: .light))
                            .shadow(radius: 4)
                    }
                }
                
                if item.fileSize > 0 && !isSelected {
                    Text(item.formattedSize)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .foregroundColor(.white)
                        .padding(6)
                }
            }
            .onAppear { fetchImage(size: geo.size, scale: displayScale) }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func fetchImage(size: CGSize, scale: CGFloat) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        manager.requestImage(for: item.asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { result, _ in
            if let result = result { self.image = result }
        }
    }
}
