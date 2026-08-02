import SwiftUI
import UserNotifications

enum AutoplayLocation: String, CaseIterable {
    case both = "Both"
    case home = "Home"
    case detail = "Details"
}

enum PlaybackStyle: String, CaseIterable {
    case resume = "Resume"
    case startOver = "Start Over"
}

struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var tmdbKey = ""
    @State private var didSave = false
    @State private var showSignOutConfirm = false
    @State private var showAppIconPicker = false
    @State private var showEasterEggAlert = false
    @State private var isKeyRevealed = false
    @AppStorage("hasSeenIconEasterEggAlert") private var hasSeenIconEasterEggAlert = false

    private var savedIdentity: String {
        UserDefaults.standard.string(forKey: "publicmetadb.user.identity") ?? ""
    }
    
    private var userName: String {
        settings.contributorName.isEmpty ? "Signed In" : settings.contributorName
    }

    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = false
    @AppStorage("autoPlayTrailers") private var autoPlayTrailers = true
    @AppStorage("trailersStartMuted") private var trailersStartMuted = true
    @AppStorage("autoplayLocation") private var autoplayLocation: AutoplayLocation = .both
    @AppStorage("playbackStyle") private var playbackStyle: PlaybackStyle = .resume
    @AppStorage("convertRatings") private var convertRatings = false
    @State private var isClearingCache = false
    @State private var cacheCleared = false
    @State private var showClearCacheConfirm = false
    @State private var currentCacheSize: String = "Calculating..."

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                
                // Profile Dashboard Widget
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: "00C9FF"), Color(hex: "92FE9D")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 84, height: 84)
                            .shadow(color: Color(hex: "00C9FF").opacity(0.4), radius: 12, x: 0, y: 6)
                        
                        Text(String(userName.prefix(2)).uppercased())
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 10)
                    
                    VStack(spacing: 6) {
                        Text("Hello, \(userName)!")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(GlassTheme.primaryText)
                        if !savedIdentity.isEmpty {
                            Text(savedIdentity)
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.secondaryText)
                        }
                    }
                    
                    Button {
                        showSignOutConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "power")
                            Text("Disconnect")
                                .fontWeight(.bold)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 28)
                        .background(Color.red.opacity(0.85), in: Capsule())
                        .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .confirmationDialog("Disconnect Account", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                        Button("Disconnect", role: .destructive) {
                            AuthService.shared.logout()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("You'll need to sign in again to access your data.")
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .liquidGlass()
                
                // 2-Column Dashboard Grid
                LazyVGrid(columns: columns, spacing: 16) {
                    // Notifications Widget
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: pushNotificationsEnabled ? "bell.badge.fill" : "bell.slash.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.orange)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Push Alerts")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(GlassTheme.primaryText)
                            Text("Episode Drops")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        
                        Toggle("", isOn: $pushNotificationsEnabled)
                            .labelsHidden()
                            .tint(.orange)
                            .onChange(of: pushNotificationsEnabled) { newValue in
                                if newValue { requestNotificationPermission() }
                            }
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .liquidGlass()
                    
                    // Storage Widget
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(cacheCleared ? Color.green.opacity(0.15) : Color.purple.opacity(0.15))
                                .frame(width: 64, height: 64)
                            
                            if isClearingCache {
                                ProgressView().tint(GlassTheme.primaryText)
                            } else {
                                Image(systemName: cacheCleared ? "checkmark.seal.fill" : "internaldrive.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(cacheCleared ? .green : .purple)
                            }
                        }
                        
                        VStack(spacing: 6) {
                            Text("Storage")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(cacheCleared ? .green : GlassTheme.primaryText)
                            Text(cacheCleared ? "All Clean!" : currentCacheSize)
                                .font(.caption)
                                .foregroundStyle(GlassTheme.secondaryText)
                        }
                        
                        Button {
                            showClearCacheConfirm = true
                        } label: {
                            Text(cacheCleared ? "DONE" : "CLEAR")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(cacheCleared ? Color.green : Color.purple.opacity(0.8), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .confirmationDialog("Clear Cache", isPresented: $showClearCacheConfirm, titleVisibility: .visible) {
                            Button("Clear Cache", role: .destructive) {
                                Task {
                                    withAnimation { isClearingCache = true }
                                    URLCache.shared.removeAllCachedResponses()
                                    try? await Task.sleep(nanoseconds: 800_000_000)
                                    withAnimation {
                                        isClearingCache = false
                                        cacheCleared = true
                                        updateCacheSize()
                                    }
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    withAnimation { cacheCleared = false }
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will manually free up \(currentCacheSize) of space. Note that the app automatically resets the cache when it reaches 2 GB.")
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .liquidGlass()
                }

                // Media Experience Widget
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.pink.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.pink)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Play Trailers")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(GlassTheme.primaryText)
                            Text("Cinematic Experience")
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.secondaryText)
                        }
                        Spacer()
                    }
                    
                    VStack(spacing: 16) {
                        Toggle(isOn: $autoPlayTrailers) {
                            Text("Auto-Play Trailers")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GlassTheme.primaryText)
                        }
                        .tint(.pink)
                        
                        Toggle(isOn: $trailersStartMuted) {
                            Text("Start Muted")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GlassTheme.primaryText)
                        }
                        .tint(.pink)
                        .disabled(!autoPlayTrailers)
                        .opacity(autoPlayTrailers ? 1.0 : 0.5)
                        
                        if autoPlayTrailers {
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Play On")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(GlassTheme.secondaryText)
                                    Picker("Play On", selection: $autoplayLocation) {
                                        ForEach(AutoplayLocation.allCases, id: \.self) { location in
                                            Text(location.rawValue).tag(location)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Playback Style")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(GlassTheme.secondaryText)
                                    Picker("Playback Style", selection: $playbackStyle) {
                                        ForEach(PlaybackStyle.allCases, id: \.self) { style in
                                            Text(style.rawValue).tag(style)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .padding(20)
                .liquidGlass()
                
                // 2-Column Dashboard Grid: Ratings & Customization
                LazyVGrid(columns: columns, spacing: 16) {
                    // Ratings Widget
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.yellow)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Ratings")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(GlassTheme.primaryText)
                            Text("Convert Scales")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        
                        Toggle("", isOn: $convertRatings)
                            .labelsHidden()
                            .tint(.yellow)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .liquidGlass()
                    // Poster Customization Widget
                    VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "photo.artframe")
                                    .font(.system(size: 26))
                                    .foregroundStyle(.blue)
                            }
                            
                            VStack(spacing: 6) {
                                Text("Posters")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(GlassTheme.primaryText)
                                Text("Appearance")
                                    .font(.caption)
                                    .foregroundStyle(GlassTheme.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            
                            NavigationLink {
                                PosterCustomizationView()
                            } label: {
                                Text("STYLE")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.8), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .liquidGlass()
                }
                
                // API Config Wide Widget
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.cyan.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: "server.rack")
                                .font(.system(size: 20))
                                .foregroundStyle(.cyan)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TMDB Metadata")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(GlassTheme.primaryText)
                            Text("API Key")
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.secondaryText)
                        }
                        Spacer()
                        
                        if settings.isTMDBConfigured {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(GlassTheme.secondaryText)
                        
                        if isKeyRevealed {
                            ScrollView(.horizontal, showsIndicators: false) {
                                TextField("Paste your API Key here", text: $tmdbKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(GlassTheme.primaryText)
                                    .submitLabel(.done)
                                    .onSubmit { save() }
                                    .onChange(of: tmdbKey) { _ in save() }
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                SecureField("Paste your API Key here", text: $tmdbKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(GlassTheme.primaryText)
                                    .submitLabel(.done)
                                    .onSubmit { save() }
                                    .onChange(of: tmdbKey) { _ in save() }
                                    .frame(minWidth: max(250, CGFloat(tmdbKey.count * 12)), alignment: .leading)
                            }
                        }
                        
                        Button {
                            isKeyRevealed.toggle()
                        } label: {
                            Image(systemName: isKeyRevealed ? "eye.slash" : "eye")
                                .foregroundStyle(GlassTheme.secondaryText)
                                .font(.system(size: 14))
                        }
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .padding(20)
                .liquidGlass()
                
                // Footer
                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                
                VStack(spacing: 12) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "f12711"), Color(hex: "f5af19")], startPoint: .top, endPoint: .bottom))
                        .onLongPressGesture {
                            showAppIconPicker = true
                        }
                    
                    VStack(spacing: 4) {
                        Text("Argus")
                            .font(.headline.weight(.black))
                            .foregroundStyle(GlassTheme.primaryText)
                        Text("Version \(appVersion) • Made with ❤️ by AncientFalcon")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.top, 16)
                .padding(.bottom, 40)

            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .navigationDestination(isPresented: $showAppIconPicker) {
                AppIconPickerView()
            }
        }
        .background(GlassTheme.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            tmdbKey = settings.tmdbAPIKey
            updateCacheSize()
            
            if !hasSeenIconEasterEggAlert {
                // Short delay so it feels natural when they open settings
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    showEasterEggAlert = true
                    hasSeenIconEasterEggAlert = true
                }
            }
        }
        .alert("Customize Your App Icon", isPresented: $showEasterEggAlert) {
            Button("Got it!", role: .cancel) { }
        } message: {
            Text("Did you know? You can long-press the glowing Argus eye icon at the bottom of this screen to customize your app icon!")
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    self.pushNotificationsEnabled = false
                }
            }
        }
    }

    private func save() {
        settings.saveTMDBKey(tmdbKey)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { didSave = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { didSave = false }
    }
    
    private func updateCacheSize() {
        let size = URLCache.shared.currentDiskUsage
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        currentCacheSize = formatter.string(fromByteCount: Int64(size))
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
