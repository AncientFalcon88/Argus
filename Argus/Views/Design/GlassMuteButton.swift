import SwiftUI

struct GlassMuteButton: View {
    @Binding var isMuted: Bool
    
    var body: some View {
        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 44, height: 44) // 44x44 tappable area
            .background {
                Circle()
                    .fill(.regularMaterial)
                    .environment(\.colorScheme, .dark)
                    .frame(width: 32, height: 32) // Visual circle size to match native back button
            }
            .contentShape(Circle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isMuted.toggle()
                }
            }
    }
}
