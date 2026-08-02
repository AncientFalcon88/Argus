import SwiftUI

struct WhyThisSheetView: View {
    let item: CatalogItem
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                // Background exactly like "genres" pop up
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Drag handle
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 40, height: 4)
                            .padding(.top, 8)
                        Spacer()
                    }
                    
                    // "WHY THIS ?" text
                    Text("WHY THIS ?")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
                    
                    // Match and score
                    HStack {
                        Text("\(item.calculatedPercentage) match")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        if let score = item.matchScore {
                            Text("• score \(String(format: "%.2f", score))")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Reasons List
                    if let reasons = item.matchReasons, !reasons.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(reasons, id: \.self) { reason in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: iconForReason(reason))
                                        .font(.system(size: 18, weight: .regular, design: .rounded))
                                        .foregroundColor(.gray)
                                        .frame(width: 24)
                                    Text(reason)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    } else {
                        Text("No specific reasons available.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Footer details
                    HStack {
                        if let votes = item.voteCount {
                            Text("\(votes) votes")
                        }
                        if let pop = item.popularityScore {
                            Text("• Popularity \(Int(pop))")
                        }
                        if let lang = item.originalLanguage {
                            Text("• \(lang)")
                        }
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .preferredColorScheme(.dark)
        }
    }
    
    private func iconForReason(_ reason: String) -> String {
        let lowercased = reason.lowercased()
        if lowercased.contains("genre") { return "chart.pie.fill" }
        if lowercased.contains("language") { return "globe" }
        if lowercased.contains("decade") || lowercased.contains("year") { return "calendar" }
        if lowercased.contains("director") || lowercased.contains("actor") || lowercased.contains("crew") { return "person.fill" }
        if lowercased.contains("cut") || lowercased.contains("underseen") || lowercased.contains("gem") { return "sparkles" }
        return "info.circle.fill"
    }
}
