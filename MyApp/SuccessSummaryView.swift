import SwiftUI

struct SuccessSummaryView: View {
    let freedSpace: String
    let itemCount: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                Text("CLEANUP COMPLETE")
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .foregroundColor(.white)
                    .tracking(4)
                
                VStack(spacing: 8) {
                    Text("TOTAL SPACE RECOVERED")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(2)
                    
                    Text(freedSpace)
                        .font(.system(size: 56, weight: .heavy, design: .serif))
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                
                Text("Removed \(itemCount) item(s) from your device.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Text("RETURN TO DASHBOARD")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(Color.white)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}
