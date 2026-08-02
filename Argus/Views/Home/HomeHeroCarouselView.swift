import SwiftUI
import AVKit

struct HomeHeroCarouselView: View {
    let items: [HeroCarouselItem]
    @State private var scrolledIndex: Int? = 0
    
    @AppStorage("autoPlayTrailers") private var autoPlayTrailers = true
    @AppStorage("autoplayLocation") private var autoplayLocation: AutoplayLocation = .both
    @AppStorage("playbackStyle") private var playbackStyle: PlaybackStyle = .resume
    @AppStorage("trailersStartMuted") private var trailersStartMuted = true
    @AppStorage("convertRatings") private var convertRatings = false
    @State private var isSharedMuted = true
    
    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            GeometryReader { geo in
                let minY = geo.frame(in: .global).minY
                let isScrollingDown = minY > 0
                let offset = isScrollingDown ? -minY : 0
                let height = UIScreen.main.bounds.width * 1.65 + (isScrollingDown ? minY : 0)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            MediaDetailLink(route: MediaDetailRoute(tmdbId: item.tmdbId, mediaType: item.mediaType)) {
                                HeroCarouselCard(
                                    item: item,
                                    isFirst: index == 0,
                                    isLast: index == items.count - 1,
                                    isCurrentItem: index == (scrolledIndex ?? 0),
                                    isMuted: $isSharedMuted
                                )
                                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                        let isRubberBanding = (index == 0 && phase.value < 0) || (index == items.count - 1 && phase.value > 0)
                                        let phaseValue = isRubberBanding ? 0 : phase.value
                                        
                                        let scale = 1.0 - abs(phaseValue) * 0.15
                                        let rotation = phaseValue * -20
                                        let offsetX = phaseValue * -50
                                        let offsetY = abs(phaseValue) * 15
                                        let opacity = 1.0 - abs(phaseValue) * 0.4
                                        let blur = abs(phaseValue) * 2
                                        
                                        return content
                                            .scaleEffect(scale)
                                            .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                                            .offset(x: offsetX, y: offsetY)
                                            .opacity(opacity)
                                            .blur(radius: blur)
                                    }
                            }
                            .id(index)
                            .containerRelativeFrame(.horizontal)
                            .buttonStyle(.plain)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrolledIndex)
                .frame(width: geo.size.width, height: height)
                .offset(y: offset)
                .onAppear {
                    let defaultMuted = UserDefaults.standard.object(forKey: "trailersStartMuted") != nil ? trailersStartMuted : true
                    isSharedMuted = defaultMuted
                }
                .overlay(alignment: .bottom) {
                    if items.count > 1 {
                        LiquidGlassPageIndicator(numberOfPages: items.count, currentIndex: scrolledIndex ?? 0)
                            .padding(.bottom, 46) // Lifted onto the hero fade
                            .offset(y: offset)
                    }
                }
            }
            .frame(height: UIScreen.main.bounds.width * 1.65)
        }
    }
}

private struct HeroCarouselCard: View {
    let item: HeroCarouselItem
    let isFirst: Bool
    let isLast: Bool
    let isCurrentItem: Bool
    @Binding var isMuted: Bool
    
    @AppStorage("autoPlayTrailers") private var autoPlayTrailers = true
    @AppStorage("autoplayLocation") private var autoplayLocation: AutoplayLocation = .both
    @AppStorage("playbackStyle") private var playbackStyle: PlaybackStyle = .resume
    @AppStorage("convertRatings") private var convertRatings = false
    
    @State private var player: AVPlayer?
    @State private var isVideoReady = false
    @State private var playTask: Task<Void, Never>?
    
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        GeometryReader { geo in
            let globalFrame = geo.frame(in: .global)
            let minX = globalFrame.minX
            let minY = globalFrame.minY
            let screenWidth = UIScreen.main.bounds.width
            
            let isStretchingLeft = isFirst && minX > 0
            let isStretchingRight = isLast && globalFrame.maxX < screenWidth
            
            let extraWidth = isStretchingLeft ? minX : (isStretchingRight ? screenWidth - globalFrame.maxX : 0)
            let xOffset = isStretchingLeft ? -minX / 2 : (isStretchingRight ? extraWidth / 2 : 0)
            
            let isVerticallyVisible = minY > -(geo.size.height) // Keep playing until completely off screen
            let shouldPlay = isCurrentItem && isVerticallyVisible
            
            ZStack(alignment: .bottom) {
                // Background Poster and Video wrapped together for masking
                ZStack(alignment: .bottom) {
                    CachedImage(url: item.posterURL ?? item.logoURL) {
                        ZStack {
                            Rectangle().fill(Color.gray.opacity(0.2))
                            Image(systemName: item.mediaType == .movie ? "film" : (item.mediaType == .tv ? "tv" : "person.fill"))
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width + extraWidth, height: geo.size.height)
                    .clipped()
                    
                    if autoPlayTrailers {
                        if let player = player {
                            HeroVideoPlayer(player: player)
                                .ignoresSafeArea()
                                .scaleEffect(1.35) // Zoom in to crop out baked-in letterboxing from ultra-wide trailers
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width + extraWidth, height: geo.size.height)
                                .clipped()
                                .opacity(isVideoReady && shouldPlay ? 1.0 : 0.0)
                                .blur(radius: isVideoReady && shouldPlay ? 0 : 20)
                                .animation(.easeInOut(duration: 1.5), value: isVideoReady && shouldPlay)
                        }
                    }
                }
                .ignoresSafeArea()
                .offset(x: xOffset)
                
                // Top fade for status bar readability
                LinearGradient(
                    colors: [.black.opacity(0.7), .black.opacity(0.3), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width + extraWidth, height: 180)
                .frame(maxHeight: .infinity, alignment: .top)
                .offset(x: xOffset)
                .allowsHitTesting(false)
                .ignoresSafeArea()
                
                // Liquid Glass blur for text readability (instead of harsh black)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black.opacity(0.7), location: 0.3),
                                .init(color: .black, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: geo.size.width + extraWidth, height: 420)
                    .offset(x: xOffset)
                    .allowsHitTesting(false)
                
                // Final pure black fade only at the very bottom edge to merge seamlessly with the app background
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.1), location: 0.25),
                        .init(color: .black.opacity(0.4), location: 0.5),
                        .init(color: .black.opacity(0.8), location: 0.75),
                        .init(color: .black, location: 0.9),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width + extraWidth, height: 180)
                .offset(x: xOffset)
                .allowsHitTesting(false)
                
                VStack(spacing: 12) {
                    // Logo or Title
                    if let logoURL = item.logoURL {
                        CachedImage(url: logoURL) {
                            Text(item.title)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geo.size.width * 0.7, maxHeight: 100)
                        .padding(.bottom, 8)
                    } else {
                        Text(item.title)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.bottom, 8)
                    }
                    
                    // Info Pills
                    HStack(spacing: 8) {
                        HeroMetadataCapsule(text: item.mediaType == .tv ? "Series" : "Movie")
                        
                        if let year = item.displayYear {
                            HeroMetadataCapsule(text: year)
                        }
                        if let runtime = item.displayRuntime {
                            HeroMetadataCapsule(text: runtime)
                        }
                        if let contentRating = item.contentRating {
                            HeroMetadataCapsule(text: contentRating)
                        }
                        if (item.pmdbAverageRating ?? 0) > 0 || (item.voteAverage ?? 0) > 0 {
                            HeroMetadataRatingCapsule(voteAverage: item.voteAverage ?? 0, pmdbRating: item.pmdbAverageRating)
                        }
                    }
                    
                    // Synopsis
                    if !item.overview.isEmpty {
                        Text(item.overview)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.50))
                            .lineSpacing(2)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    }
                    
                    // Rating PNGs
                    if let communityRatings = item.communityRatings {
                        let validTags = ["IM", "RT", "MC", "LB", "PC", "TM", "TR", "AN", "ML", "RE"]
                        let pngRatings = communityRatings.filter { validTags.contains($0.shortLabel) }
                        
                        if !pngRatings.isEmpty {
                            let importance: [String: Int] = ["IM": 1, "RT": 2, "MC": 3, "TM": 4, "LB": 5, "TR": 6, "PC": 7, "AN": 8, "ML": 9, "RE": 10]
                            let sortedRatings = pngRatings.sorted { (importance[$0.shortLabel] ?? 99) < (importance[$1.shortLabel] ?? 99) }
                            
                            HStack(spacing: 8) {
                                ForEach(Array(sortedRatings.prefix(6)), id: \.id) { rating in
                                    HStack(spacing: 6) {
                                        Image("logo_hero_\(rating.shortLabel)")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 14)
                                        
                                        let scoreText = convertRatings ? convertedScoreTextFn(rating.averageScore, label: rating.shortLabel) : convertedScoreTextFn(rating.averageScore, label: rating.shortLabel)
                                        Text(scoreText)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        ZStack {
                                            Capsule().fill(.ultraThinMaterial)
                                            
                                            let tintColors: [Color]? = {
                                                switch rating.shortLabel {
                                                case "IM": return [Color(red: 245/255, green: 197/255, blue: 24/255)]
                                                case "RE": return [Color(red: 0.83, green: 0.68, blue: 0.21)]
                                                case "TR": return [.purple]
                                                case "AN": return [Color(red: 0.0, green: 0.4, blue: 0.8)]
                                                case "LB": return [
                                                    Color(red: 1.0, green: 0.5, blue: 0.0),
                                                    Color(red: 1.0, green: 0.5, blue: 0.0),
                                                    Color(red: 0.0, green: 0.88, blue: 0.33),
                                                    Color(red: 0.0, green: 0.88, blue: 0.33),
                                                    Color(red: 0.25, green: 0.74, blue: 0.96),
                                                    Color(red: 0.25, green: 0.74, blue: 0.96)
                                                ]
                                                case "RT": return [Color(red: 250/255, green: 50/255, blue: 10/255)]
                                                case "PC": return [.red, .red, .yellow, .yellow]
                                                case "MC": return [.yellow, .black]
                                                case "TM": return [.teal]
                                                case "ML": return [Color(red: 0.2, green: 0.5, blue: 1.0)]
                                                default: return nil
                                                }
                                            }()
                                            
                                            if let tints = tintColors {
                                                let gradientOpacity = rating.shortLabel == "AN" ? 0.25 : 0.4
                                                let gradientColors = tints.map { $0.opacity(gradientOpacity) } + [Color.clear]
                                                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    )
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .frame(width: geo.size.width)
                .padding(.bottom, 80) // Much more space so indicator does not overlap text
                .toolbar {
                    if autoPlayTrailers && isVideoReady && isCurrentItem && minY > -150 {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    isMuted.toggle()
                                }
                            }) {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                    }
                }
            }
            .compositingGroup()
            .frame(width: geo.size.width, height: geo.size.height)
            .onChange(of: shouldPlay) { newValue in
                handleVisibilityChange(isVisible: newValue)
            }
            .onChange(of: isMuted) { newValue in
                player?.isMuted = newValue
            }
            .onAppear {
                if shouldPlay {
                    handleVisibilityChange(isVisible: true)
                }
            }
            .onDisappear {
                handleVisibilityChange(isVisible: false)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    if shouldPlay && appState.selectedTab == .home {
                        player?.play()
                    }
                } else {
                    player?.pause()
                }
            }
            .onChange(of: appState.selectedTab) { newTab in
                if newTab == .home {
                    if shouldPlay && scenePhase == .active {
                        player?.play()
                    }
                } else {
                    player?.pause()
                }
            }
        }
    }
    
    private func handleVisibilityChange(isVisible: Bool) {
        if isVisible {
            guard autoPlayTrailers && (autoplayLocation == .both || autoplayLocation == .home) else { return }
            guard let url = item.trailerURL else { return }
            if player == nil {
                let newPlayer = AVPlayer(url: url)
                newPlayer.isMuted = isMuted
                // Loop the video
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: newPlayer.currentItem, queue: .main) { _ in
                    newPlayer.seek(to: .zero)
                    newPlayer.play()
                }
                self.player = newPlayer
            } else {
                if playbackStyle == .startOver {
                    player?.seek(to: .zero)
                }
                player?.isMuted = isMuted
            }
            playTask?.cancel()
            playTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if !Task.isCancelled {
                    player?.play()
                    withAnimation {
                        isVideoReady = true
                    }
                }
            }
        } else {
            playTask?.cancel()
            playTask = nil
            player?.pause()
            withAnimation(.easeOut(duration: 0.5)) {
                isVideoReady = false
            }
        }
    }
}

// MARK: - Video Player wrapper
struct HeroVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerView = uiView as? PlayerView {
            playerView.playerLayer.player = player
        }
    }
    
    class PlayerView: UIView {
        override class var layerClass: AnyClass {
            return AVPlayerLayer.self
        }
        
        var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }
    }
}

struct SkeletonHeroCarouselView: View {
    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let isScrollingDown = minY > 0
            let offset = isScrollingDown ? -minY : 0
            let height = UIScreen.main.bounds.width * 1.65 + (isScrollingDown ? minY : 0)
            
            ZStack(alignment: .bottom) {
                // Skeleton Poster
                ShimmerView()
                    .frame(width: geo.size.width, height: height)
                
                // Top fade for status bar readability
                LinearGradient(
                    colors: [.black.opacity(0.7), .black.opacity(0.3), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: 180)
                .frame(maxHeight: .infinity, alignment: .top)
                
                // Gradients to blend smoothly with the black background
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.8), location: 0.5),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: 350)
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: 80)
                
                VStack(spacing: 12) {
                    // Logo Skeleton
                    ShimmerView()
                        .frame(width: 180, height: 60)
                        .cornerRadius(12)
                        .padding(.bottom, 8)
                    
                    // Info Pills Skeleton
                    HStack(spacing: 8) {
                        ShimmerView().frame(width: 48, height: 22).cornerRadius(11)
                        ShimmerView().frame(width: 36, height: 22).cornerRadius(11)
                        ShimmerView().frame(width: 54, height: 22).cornerRadius(11)
                        ShimmerView().frame(width: 42, height: 22).cornerRadius(11)
                    }
                    
                    // Synopsis Skeleton
                    VStack(spacing: 6) {
                        ShimmerView().frame(width: 280, height: 12).cornerRadius(4)
                        ShimmerView().frame(width: 240, height: 12).cornerRadius(4)
                        ShimmerView().frame(width: 160, height: 12).cornerRadius(4)
                    }
                    
                    // Rating PNGs Skeleton
                    HStack(spacing: 8) {
                        ShimmerView().frame(width: 60, height: 26).cornerRadius(13)
                        ShimmerView().frame(width: 50, height: 26).cornerRadius(13)
                        ShimmerView().frame(width: 55, height: 26).cornerRadius(13)
                        ShimmerView().frame(width: 65, height: 26).cornerRadius(13)
                        ShimmerView().frame(width: 45, height: 26).cornerRadius(13)
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 80) // Much more space so indicator does not overlap text
            }
            .offset(y: offset)
            .redacted(reason: .placeholder)
        }
        .frame(height: UIScreen.main.bounds.width * 1.65)
    }
}

struct LiquidGlassPageIndicator: View {
    let numberOfPages: Int
    let currentIndex: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                let distance = abs(currentIndex - index)
                
                if distance == 0 {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 22, height: 8)
                        .shadow(color: .white.opacity(0.6), radius: 4, x: 0, y: 0)
                } else if distance < 4 {
                    let size: CGFloat = 8 - CGFloat(distance) * 1.5
                    let opacity: Double = 0.8 - Double(distance) * 0.2
                    Circle()
                        .fill(Color.white.opacity(opacity))
                        .frame(width: max(size, 4), height: max(size, 4))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: currentIndex)
    }
}

struct HeroEmptyStateView: View {
    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let isScrollingDown = minY > 0
            let offset = isScrollingDown ? -minY : 0
            let height = 400 + (isScrollingDown ? minY : 0)
            
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.05), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: height)
                
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    VStack(spacing: 8) {
                        Text("You're All Caught Up!")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(.white)
                        
                        Text("Time to discover new shows and movies to add to your Watchlist.")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .padding(.top, (isScrollingDown ? minY / 2 : 0) + 60)
            }
            .frame(width: geo.size.width, height: height)
            .offset(y: offset)
        }
        .frame(height: 400)
    }
}
