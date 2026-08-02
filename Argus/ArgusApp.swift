import SwiftData
import SwiftUI
import AVFoundation

@main
struct ArgusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appState = AppState()
    @State private var showSplash = true

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedResumePoint.self,
            CachedWatchEntry.self,
            CachedMediaList.self,
            SyncMetadata.self,
            SavedPublicList.self,
            FavoriteItem.self,
            CachedListItem.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(appState)
                    .environmentObject(SettingsStore.shared)
                
                if appState.isCertifiedNerd {
                    VStack {
                        Text("CERTIFIED")
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                        Text("NERD")
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                    }
                    .font(.system(size: 80, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.red.opacity(0.4))
                    .rotationEffect(.degrees(-20))
                    .allowsHitTesting(false)
                    .padding(.horizontal, 20)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
                }
                
                // Keep structurally stable to prevent layout recalculation freezes
                SplashView(isPresented: $showSplash)
                    .zIndex(1)
                    .allowsHitTesting(showSplash)
            }
            .dynamicTypeSize(.large)
        }
        .modelContainer(sharedModelContainer)
    }
}

struct HoleShape: Shape {
    var radius: CGFloat
    
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let hole = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        path.addEllipse(in: hole)
        return path
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        // Configure URLCache to allow up to 250MB in memory and 2GB on disk
        let memoryCapacity = 250 * 1024 * 1024 // 250 MB
        let diskCapacity = 2000 * 1024 * 1024 // 2 GB
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "pmdb_cache")
        URLCache.shared = cache
        
        // Configure Audio Session for video playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge, .list])
    }
}

class PlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var player: AVPlayer? {
        get { (layer as? AVPlayerLayer)?.player }
        set { (layer as? AVPlayerLayer)?.player = newValue }
    }
}

struct SplashVideoPlayer: UIViewRepresentable {
    let videoName: String
    let onFinish: () -> Void

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black
        (view.layer as? AVPlayerLayer)?.videoGravity = .resizeAspect
        
        if let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
            let player = AVPlayer(url: url)
            player.isMuted = true // Ensure video audio is muted
            view.player = player
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                DispatchQueue.main.async {
                    onFinish()
                }
            }
            
            player.play()
        }
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}
}



struct SplashView: View {
    @Binding var isPresented: Bool
    @State private var maskProgress: CGFloat = 0.0
    @State private var blurRadius: CGFloat = 20.0
    @State private var videoOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Strict black background
            Color.black
                .ignoresSafeArea()
            
            if Bundle.main.url(forResource: "splashscreeneye", withExtension: "mp4") != nil {
                SplashVideoPlayer(videoName: "splashscreeneye") {
                    dismissSplash()
                }
                .scaleEffect(0.6) // Zoom out the video
                .blur(radius: blurRadius)
                .opacity(videoOpacity)
                .ignoresSafeArea()
                .disabled(true) // Disable any possible interactions
                .onAppear {
                    withAnimation(.easeOut(duration: 1.5)) {
                        blurRadius = 0.0
                        videoOpacity = 1.0
                    }
                }
                
                // Tight elliptical overlay to cover the gray bounding box
                RadialGradient(
                    gradient: Gradient(colors: [.clear, .clear, .black.opacity(0.9), .black]),
                    center: .center,
                    startRadius: UIScreen.main.bounds.width * 0.15,
                    endRadius: UIScreen.main.bounds.width * 0.3
                )
                .scaleEffect(x: 1.6, y: 0.8) // Stretch into a wide ellipse to match the eye
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(videoOpacity)
            } else {
                // Failsafe if video is missing
                Color.black.ignoresSafeArea()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            dismissSplash()
                        }
                    }
            }
        }
        .clipShape(HoleShape(radius: maskProgress * 1500), style: FillStyle(eoFill: true))
        .ignoresSafeArea()
    }
    
    private func dismissSplash() {
        // Run the visual animation
        withAnimation(.easeOut(duration: 2.5)) {
            maskProgress = 1.0
        }
        
        // Tell the App to drop hit testing immediately
        isPresented = false
    }
}
