import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenTutorial: Bool
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            ThemeBackground()
            
            TabView(selection: $currentPage) {
                // Page 1
                OnboardingPage(
                    icon: "magnifyingglass.circle.fill",
                    title: "Smart Scanning",
                    description: "Effortlessly find large files, duplicates, and blurry photos that are cluttering your device."
                )
                .tag(0)
                
                // Page 2
                OnboardingPage(
                    icon: "arrow.down.right.and.arrow.up.left.circle.fill",
                    title: "Lossless Compression",
                    description: "Shrink massive video files instantly without sacrificing visual quality."
                )
                .tag(1)
                
                // Page 3
                OnboardingPage(
                    icon: "lock.shield.fill",
                    title: "Secure Vault",
                    description: "Hide your most sensitive photos and videos behind Face ID and military-grade encryption."
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            VStack {
                Spacer()
                
                if currentPage == 2 {
                    Button(action: {
                        Haptics.impact(.medium)
                        withAnimation(.easeInOut(duration: 0.6)) {
                            hasSeenTutorial = true
                        }
                    }) {
                        Text("GET STARTED")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.blue)
                            .cornerRadius(20)
                            .padding(.horizontal, 40)
                    }
                    .antigravityButton()
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

struct OnboardingPage: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 100))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .padding()
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 180, height: 180)
                )
                .shadow(color: .blue.opacity(0.3), radius: 30, x: 0, y: 10)
            
            Text(title)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
}
