import SwiftUI
import SwiftData
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showSettings = false
    @State private var doNotPressCount = 0

    private var isSyncing: Bool {
        appState.isSyncing || viewModel.isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Last Sync Text
                    Text(viewModel.lastSyncText)
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, -8)

                    // 4 Dashboard Options Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        
                        NavigationLink(value: ProfileStatDestination.calendar) {
                            dashboardCard(title: "Calendar", symbol: "calendar", color: .purple)
                        }
                        
                        NavigationLink(value: ProfileStatDestination.favorites) {
                            dashboardCard(title: "Favorites", symbol: "star.fill", color: .orange)
                        }
                        
                        NavigationLink(value: ProfileStatDestination.myProgress) {
                            dashboardCard(title: "My Progress", symbol: "chart.line.uptrend.xyaxis", color: .green)
                        }
                        
                        NavigationLink(value: ProfileStatDestination.myStats) {
                            dashboardCard(title: "My Stats", symbol: "chart.pie.fill", color: .blue)
                        }
                        
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .buttonStyle(.plain)

                    // Account Settings List
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            showSettings = true
                        } label: {
                            settingsRow(
                                "Settings",
                                detail: "App Dashboard & Preferences",
                                symbol: "gearshape.fill",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                            
                            Divider()
                                .padding(.horizontal, 16)
                            
                            settingsRow(
                                "API Base",
                                detail: Config.baseURL.absoluteString,
                                symbol: "link",
                                showsChevron: false
                            )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.85)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .clear, .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 0)
                    .background {
                        Ellipse()
                            .fill(Color.white.opacity(0.1))
                            .blur(radius: 60)
                            .frame(width: 300, height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    if let error = viewModel.errorMessage ?? appState.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.85))
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 40)
                    
                    // The DO NOT PRESS Easter Egg
                    ZStack {
                        if doNotPressCount > 500 {
                            Text("500 TAPS HAVE BEEN STOLEN 😈")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                                .transition(.opacity.combined(with: .scale))
                        }
                        
                        Button {
                            withAnimation(.bouncy(duration: 0.4, extraBounce: 0.3)) {
                                doNotPressCount += 1
                                if doNotPressCount > 500 {
                                    appState.isCertifiedNerd = true
                                }
                                
                                let thresholds = [1, 11, 31, 61, 101, 151, 200, 250, 301, 351, 401, 451, 490, 500]
                                if thresholds.contains(doNotPressCount) {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                } else {
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                }
                            }
                        } label: {
                        Text(buttonText)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(doNotPressCount >= 10 ? .white : .red)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.red.opacity(min(1.0, 0.1 + Double(doNotPressCount) / 50.0)))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                            .shadow(color: .red.opacity(doNotPressCount > 0 ? min(1.0, 0.6 + Double(doNotPressCount)/500) : 0), radius: 15 + CGFloat(doNotPressCount) * 0.05)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(doNotPressCount > 500 ? 0.8 : (1.0 + min(CGFloat(doNotPressCount) * 0.0003, 0.15)))
                    .offset(x: doNotPressCount > 0 && doNotPressCount <= 500 ? (doNotPressCount % 2 == 0 ? 18 : -18) : 0)
                    .offset(y: doNotPressCount > 500 ? 1000 : (doNotPressCount > 0 ? (doNotPressCount % 3 == 0 ? 15 : (doNotPressCount % 3 == 1 ? -15 : 0)) : 0))
                    .rotationEffect(.degrees(doNotPressCount > 500 ? 120 : 0))
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: doNotPressCount > 500)
                    }
                    
                }
                .padding(.bottom, 60)
            }
            .background(AppBackground())
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(for: ProfileStatDestination.self) { destination in
                switch destination {
                case .calendar: CalendarView()
                case .favorites: FavoritesView()
                case .myProgress: MyProgressView()
                case .myStats: MyStatsView()
                }
            }
            .mediaDetailDestination()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await appState.refreshAccountData()
                            await viewModel.refresh(context: modelContext)
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(GlassTheme.primaryText)
                            .padding(8)
                            .rotationEffect(.degrees(isSyncing ? 360 : 0))
                            .animation(
                                isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                value: isSyncing
                            )
                    }
                    .disabled(isSyncing)
                }
            }
            .task {
                appState.configure(context: modelContext)
                await viewModel.refresh(context: modelContext)
            }
        }
    }
    
    private func dashboardCard(title: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.6), radius: 12, x: 0, y: 4)
            
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.85)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .background {
            // Intense vibrant aura
            Circle()
                .fill(color)
                .blur(radius: 50)
                .frame(width: 130, height: 130)
                .opacity(0.5)
        }
    }
    
    private var buttonText: String {
        switch doNotPressCount {
        case 0: return "DO NOT PRESS!"
        case 1...10: return "I SAID DO NOT PRESS!! (\(doNotPressCount)/500)"
        case 11...30: return "SERIOUSLY. STOP. (\(doNotPressCount)/500)"
        case 31...60: return "WOW. YOU HAVE NO LIFE. (\(doNotPressCount)/500)"
        case 61...100: return "GO WATCH A MOVIE. (\(doNotPressCount)/500)"
        case 101...150: return "DO YOUR FINGERS HURT YET? (\(doNotPressCount)/500)"
        case 151...199: return "I'M NOT EVEN MAD. JUST IMPRESSED. (\(doNotPressCount)/500)"
        case 200...249: return "STILL GOING? WHO HURT YOU? (\(doNotPressCount)/500)"
        case 250...300: return "HALF WAY THERE, NERD. (\(doNotPressCount)/500)"
        case 301...350: return "THERE IS NO PRIZE AT THE END. (\(doNotPressCount)/500)"
        case 351...400: return "I'M RUNNING OUT OF INSULTS. (\(doNotPressCount)/500)"
        case 401...450: return "PLEASE SEEK MEDICAL ATTENTION. (\(doNotPressCount)/500)"
        case 451...490: return "ALRIGHT, I RESPECT THE GRIND. (\(doNotPressCount)/500)"
        case 491...498: return "ALMOST THERE... (\(doNotPressCount)/500)"
        case 499: return "LAST WARNING..."
        case 500: return "OKAY THAT'S IT."
        default: return "BYE."
        }
    }


    private func settingsRow(
        _ title: String,
        detail: String,
        symbol: String,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .frame(width: 28)
                .foregroundStyle(GlassTheme.primaryText)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GlassTheme.primaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(GlassTheme.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GlassTheme.secondaryText)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}


