import SwiftUI

struct ShimmerView: View {
    @State private var startPoint = UnitPoint(x: -1, y: 0.5)
    @State private var endPoint = UnitPoint(x: 0, y: 0.5)
    
    var body: some View {
        LinearGradient(
            colors: [Color(white: 0.15), Color(white: 0.25), Color(white: 0.15)],
            startPoint: startPoint,
            endPoint: endPoint
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                startPoint = UnitPoint(x: 1, y: 0.5)
                endPoint = UnitPoint(x: 2, y: 0.5)
            }
        }
    }
}

struct SkeletonCardView: View {
    let isLandscape: Bool
    var showProgressBar: Bool = false
    
    var body: some View {
        if isLandscape {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    ShimmerView()
                        .frame(width: 260, height: 174)
                        .cornerRadius(16)
                    
                    if showProgressBar {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 240, height: 4)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 8)
                    }
                }
                
                HStack(alignment: .top) {
                    ShimmerView()
                        .frame(width: 140, height: 14)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    ShimmerView()
                        .frame(width: 60, height: 12)
                        .cornerRadius(4)
                }
                .padding(.horizontal, 2)
            }
            .frame(width: 260)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ShimmerView()
                    .frame(width: 94, height: 140)
                    .cornerRadius(10)
                
                ShimmerView()
                    .frame(width: 80, height: 14)
                    .cornerRadius(4)
                
                ShimmerView()
                    .frame(width: 60, height: 12)
                    .cornerRadius(4)
            }
            .frame(width: 94)
        }
    }
}

struct SkeletonRowView: View {
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                ShimmerView()
                    .frame(width: 140, height: 16)
                    .cornerRadius(4)
                
                HStack(spacing: 8) {
                    ShimmerView()
                        .frame(width: 60, height: 18)
                        .cornerRadius(9)
                    ShimmerView()
                        .frame(width: 50, height: 18)
                        .cornerRadius(9)
                }
            }
            Spacer()
            ShimmerView()
                .frame(width: 53, height: 80)
                .cornerRadius(6)
        }
        .padding(.vertical, 8)
    }
}

struct SkeletonHomeListGlassCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShimmerView()
                .frame(height: 160)
            VStack(alignment: .leading, spacing: 6) {
                ShimmerView().frame(width: 140, height: 20).cornerRadius(4)
                HStack {
                    ShimmerView().frame(width: 60, height: 16).cornerRadius(8)
                    Spacer()
                    ShimmerView().frame(width: 80, height: 12).cornerRadius(4)
                }
            }
            .padding(16)
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }
}

struct SkeletonRecentSkipGlassCard: View {
    var body: some View {
        ZStack(alignment: .center) {
            ShimmerView()
                .frame(width: 280, height: 160)
            
            Rectangle().fill(.ultraThinMaterial)
            
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    ShimmerView().frame(width: 100, height: 16).cornerRadius(4)
                    Spacer(minLength: 0)
                    ShimmerView().frame(width: 60, height: 12).cornerRadius(4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                ShimmerView()
                    .aspectRatio(2/3, contentMode: .fit)
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(16)
            }
        }
        .frame(width: 280, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct SkeletonRecentRatingGlassCard: View {
    var body: some View {
        HStack(spacing: 0) {
            ShimmerView()
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 100, height: 150)
            
            VStack(alignment: .leading, spacing: 6) {
                ShimmerView().frame(width: 120, height: 16).cornerRadius(4)
                Spacer(minLength: 0)
                ShimmerView().frame(width: 40, height: 32).cornerRadius(8)
                ShimmerView().frame(width: 80, height: 12).cornerRadius(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 280, height: 150)
        .background(.ultraThinMaterial)
        .background(
            ZStack {
                LinearGradient(colors: [.white.opacity(0.15), .clear], startPoint: UnitPoint(x: 0.35, y: 0), endPoint: .bottomTrailing)
            }
        )
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct SkeletonRecentHighlightGlassCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShimmerView()
                .frame(width: 24, height: 24)
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 6) {
                ShimmerView().frame(height: 14).cornerRadius(4)
                ShimmerView().frame(height: 14).cornerRadius(4)
                ShimmerView().frame(height: 14).cornerRadius(4)
                ShimmerView().frame(width: 180, height: 14).cornerRadius(4)
            }
            
            ShimmerView().frame(width: 140, height: 12).cornerRadius(4)
                .padding(.top, 4)
            
            Spacer(minLength: 0)
            
            HStack(spacing: 10) {
                ShimmerView()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                
                VStack(alignment: .leading, spacing: 4) {
                    ShimmerView().frame(width: 120, height: 12).cornerRadius(4)
                    ShimmerView().frame(width: 60, height: 10).cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial).opacity(0.8))
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .frame(width: 320, height: 240)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct SkeletonDiscoverPosterCell: View {
    var customWidth: CGFloat? = nil
    var customHeight: CGFloat? = nil
    
    private let totalPadding: CGFloat = 24
    private let totalSpacing: CGFloat = 24
    
    private var posterWidth: CGFloat {
        customWidth ?? ((UIScreen.main.bounds.width - totalPadding - totalSpacing) / 3)
    }
    private var posterHeight: CGFloat {
        customHeight ?? (posterWidth * 1.5)
    }
    
    var body: some View {
        ShimmerView()
            .frame(width: posterWidth, height: posterHeight)
            .cornerRadius(16)
    }
}
