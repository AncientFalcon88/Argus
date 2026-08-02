import SwiftData
import SwiftUI

struct CalendarPlaceholderView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                Image(systemName: "calendar")
                    .font(.system(size: 64))
                    .foregroundStyle(.purple)
                Text("Calendar")
                    .font(.title.bold())
                    .foregroundStyle(GlassTheme.primaryText)
                Text("Coming soon...")
                    .font(.subheadline)
                    .foregroundStyle(GlassTheme.secondaryText)
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FavoritesPlaceholderView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                Image(systemName: "star.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                Text("Favorites")
                    .font(.title.bold())
                    .foregroundStyle(GlassTheme.primaryText)
                Text("Coming soon...")
                    .font(.subheadline)
                    .foregroundStyle(GlassTheme.secondaryText)
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MyProgressPlaceholderView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text("My Progress")
                    .font(.title.bold())
                    .foregroundStyle(GlassTheme.primaryText)
                Text("Coming soon...")
                    .font(.subheadline)
                    .foregroundStyle(GlassTheme.secondaryText)
            }
        }
        .navigationTitle("My Progress")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MyStatsPlaceholderView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                Text("My Stats")
                    .font(.title.bold())
                    .foregroundStyle(GlassTheme.primaryText)
                Text("Coming soon...")
                    .font(.subheadline)
                    .foregroundStyle(GlassTheme.secondaryText)
            }
        }
        .navigationTitle("My Stats")
        .navigationBarTitleDisplayMode(.inline)
    }
}
