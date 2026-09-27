import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("hasCompletedGuidedTour_v3") private var hasSeenTutorial = false
    
    @State private var storageInfo: StorageInfo?
    @State private var permissions = PermissionManager()
    @State private var scanner = MediaScanner()
    @State private var contactsEngine = ContactsEngine()
    @State private var photoEngine = PhotoDuplicateEngine()
    @State private var calendarEngine = CalendarEngine()
    
    @State private var animatedPercentage: Double = 0.0
    @State private var hasAppeared = false
    @State private var isBouncing = false
    @State private var hasScanned = false
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        if !hasSeenTutorial {
            GuidedTourView(hasSeenTutorial: $hasSeenTutorial)
        } else {
            mainDashboard
        }
    }
    
    var mainDashboard: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                let isScanning = scanner.isScanning || contactsEngine.isScanning || photoEngine.isScanning || calendarEngine.isScanning
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Dashboard")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : -10)
                    .animation(.easeOut(duration: 0.6), value: hasAppeared)
                    
                    // Storage Gauge
                    if let info = storageInfo {
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(Color(white: 0.12), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                                
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(animatedPercentage))
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [.cyan, .blue, .indigo, .purple, .cyan]),
                                            center: .center,
                                            startAngle: .degrees(-90),
                                            endAngle: .degrees(270)
                                        ),
                                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .animation(.interpolatingSpring(stiffness: 40, damping: 12).delay(0.3), value: animatedPercentage)
                                    .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 0)
                                
                                VStack(spacing: -2) {
                                    Text("\(Int(animatedPercentage * 100))%")
                                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                        .contentTransition(.numericText())
                                    
                                    Text("USED")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(white: 0.5))
                                        .tracking(2)
                                }
                            }
                            .frame(width: 200, height: 200)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Free Space")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(white: 0.5))
                                    Text(info.formattedFree)
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Total Capacity")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(white: 0.5))
                                    Text(info.formattedTotal)
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 32)
                        }
                        .padding(.bottom, 24)
                    }
                    
                    // Dynamic Middle Area
                    ScrollView(showsIndicators: false) {
                        if isScanning {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(.cyan)
                                    .scaleEffect(1.3)
                                Text("Analyzing device storage...")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(white: 0.6))
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .transition(.opacity)
                            
                        } else if !hasScanned {
                            VStack(spacing: 24) {
                                ZStack {
                                    Circle()
                                        .fill(Color.cyan.opacity(0.1))
                                        .frame(width: 88, height: 88)
                                    Image(systemName: "viewfinder")
                                        .font(.system(size: 32, weight: .light))
                                        .foregroundColor(.cyan)
                                }
                                
                                VStack(spacing: 8) {
                                    Text("System Ready")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Text("Initiate a scan to detect duplicate media,\nold events, and heavy files.")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(Color(white: 0.5))
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(4)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 240)
                            .transition(.scale.combined(with: .opacity))
                            
                        } else if permissions.hasDeniedAccess {
                            Button(action: { permissions.openSettings() }) {
                                Text("Open Settings to Allow Access")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(Color(white: 0.12))
                                    .cornerRadius(16)
                            }
                            .buttonStyle(AntigravityButtonStyle())
                            .padding(.horizontal, 24)
                            .padding(.top, 40)
                            
                        } else {
                            let allCards: [(id: Int, title: String, count: Int, icon: String, color: Color, view: AnyView)] = [
                                (0, "Similar", photoEngine.totalSimilarPhotos, "photo.on.rectangle.angled", .blue, AnyView(SwipeReviewView(photoEngine: photoEngine))),
                                (1, "Blurry", scanner.blurryPhotos.count, "camera.filters", .cyan, AnyView(MediaGridReviewView(title: "Blurry Photos", scanner: scanner, mediaType: .blurryPhotos))),
                                (2, "Screenshots", scanner.screenshots.count, "macwindow", .mint, AnyView(MediaGridReviewView(title: "Screenshots", scanner: scanner, mediaType: .screenshots))),
                                (3, "Large Videos", scanner.largeVideos.count, "video.fill", .indigo, AnyView(MediaGridReviewView(title: "Large Videos", scanner: scanner, mediaType: .largeVideos))),
                                (4, "Contacts", contactsEngine.totalDuplicatesFound, "person.2.fill", .green, AnyView(ContactReviewView(contactsEngine: contactsEngine))),
                                (5, "Old Events", calendarEngine.oldEvents.count, "calendar.badge.minus", .orange, AnyView(CalendarReviewView(engine: calendarEngine)))
                            ]
                            
                            let activeCards = allCards.filter { $0.count > 0 }
                            let zeroCards = allCards.filter { $0.count == 0 }
                            let orderedCards = activeCards + zeroCards
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(orderedCards, id: \.id) { card in
                                    AppleWidgetCard(
                                        title: card.title,
                                        count: card.count,
                                        icon: card.icon,
                                        accentColor: card.color,
                                        destination: card.view
                                    )
                                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 10)
                            .animation(.interpolatingSpring(stiffness: 250, damping: 20), value: orderedCards.map { $0.id })
                        }
                    }
                    
                    if hasScanned && !isScanning && !permissions.hasDeniedAccess {
                        Image(systemName: "chevron.compact.down")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(white: 0.3))
                            .offset(y: isBouncing ? 4 : -4)
                            .opacity(isBouncing ? 0.8 : 0.2)
                            .padding(.top, -8)
                            .padding(.bottom, 6)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                    isBouncing = true
                                }
                            }
                    } else {
                        Spacer(minLength: 0)
                    }
                    
                    // Footer
                    HStack(spacing: 16) {
                        NavigationLink(destination: VaultView()) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.cyan)
                                .frame(width: 64, height: 64)
                                .background(Color(white: 0.12))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(AntigravityButtonStyle())
                        
                        Button(action: {
                            Haptics.impact(.medium)
                            Task {
                                let photoAuth = await permissions.requestPhotoAccess()
                                let contactsAuth = await permissions.requestContactsAccess()
                                let calAuth = await permissions.requestCalendarAccess()
                                
                                await withTaskGroup(of: Void.self) { group in
                                    if photoAuth {
                                        group.addTask { await scanner.startScan() }
                                        group.addTask { await photoEngine.scanForDuplicates() }
                                    }
                                    if contactsAuth { group.addTask { await contactsEngine.scanContacts() } }
                                    if calAuth { group.addTask { await calendarEngine.scanCalendar() } }
                                }
                                
                                withAnimation(.spring()) {
                                    hasScanned = true
                                }
                            }
                        }) {
                            HStack {
                                if isScanning {
                                    ProgressView()
                                        .tint(.black)
                                        .padding(.trailing, 4)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isScanning ? "Analyzing..." : (hasScanned ? "Re-Scan Device" : "Scan Device"))
                            }
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                LinearGradient(colors: [.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .shadow(color: .white.opacity(0.15), radius: 10, x: 0, y: 0)
                        }
                        .buttonStyle(AntigravityButtonStyle())
                        .disabled(isScanning)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .padding(.top, 4)
                }
            }
            .onAppear {
                storageInfo = StorageManager.getDeviceStorage()
                if let info = storageInfo {
                    animatedPercentage = info.usedPercentage
                }
                withAnimation {
                    hasAppeared = true
                }
            }
        }
    }
}

// MARK: - Premium Guided Tour View
struct GuidedTourView: View {
    @Binding var hasSeenTutorial: Bool
    @State private var currentPage = 0
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(currentPage == index ? Color.white : Color(white: 0.2))
                            .frame(height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                TabView(selection: $currentPage) {
                    GuidedTourPage(
                        icon: "sparkles",
                        iconColor: .cyan,
                        title: "Intelligent Clean",
                        subtitle: "VOID automatically identifies blurry photos, duplicate contacts, and heavy files clogging your device."
                    ).tag(0)
                    
                    GuidedTourPage(
                        icon: "video.badge.waveform",
                        iconColor: .indigo,
                        title: "Lossless Compression",
                        subtitle: "Shrink massive 4K video files down to lightweight formats without losing visual quality."
                    ).tag(1)
                    
                    GuidedTourPage(
                        icon: "lock.shield.fill",
                        iconColor: .mint,
                        title: "Face ID Vault",
                        subtitle: "Lock your most sensitive media away in an encrypted local sandbox secured by your biometrics."
                    ).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                .onChange(of: currentPage) {
                    Haptics.impact(.light)
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        Haptics.impact(.medium)
                        if currentPage < 2 {
                            withAnimation { currentPage += 1 }
                        } else {
                            withAnimation(.easeOut(duration: 0.5)) {
                                hasSeenTutorial = true
                            }
                        }
                    }) {
                        Text(currentPage == 2 ? "Enter VOID" : "Continue")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 0)
                    }
                    .buttonStyle(AntigravityButtonStyle())
                    
                    if currentPage < 2 {
                        Button("Skip Tour") {
                            withAnimation(.easeOut(duration: 0.5)) { hasSeenTutorial = true }
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(white: 0.4))
                        .padding(.vertical, 8)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    isVisible = true
                }
            }
        }
    }
}

struct GuidedTourPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 160, height: 160)
                
                Circle()
                    .stroke(iconColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 180, height: 180)
                
                Image(systemName: icon)
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(iconColor)
                    .shadow(color: iconColor.opacity(0.5), radius: 20, x: 0, y: 0)
            }
            .padding(.bottom, 20)
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(Color(white: 0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

// MARK: - Native Apple Pro Widget Card
struct AppleWidgetCard<Destination: View>: View {
    let title: String
    let count: Int
    let icon: String
    let accentColor: Color
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(accentColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(white: 0.3))
                }
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(white: 0.6))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(1, contentMode: .fill)
            .background(Color(white: 0.1))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.15), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
        }
        .buttonStyle(AntigravityButtonStyle())
    }
}

// MARK: - Styles
struct AntigravityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.2), value: configuration.isPressed)
    }
}
