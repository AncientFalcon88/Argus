import Foundation

struct ProgressTimeDistribution: Hashable {
    let morning: Int
    let afternoon: Int
    let evening: Int
    let night: Int
    var total: Int { morning + afternoon + evening + night }
}

struct ProgressMonthlyStat: Identifiable {
    let id = UUID()
    let month: String
    let count: Int
}

struct ProgressDayStat: Identifiable {
    let id = UUID()
    let day: String
    let count: Int
}

struct ProgressGenreStat: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let count: Int
}

struct ProgressPersonStat: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let profilePath: String?
    let tmdbId: Int
}

struct ProgressActivityDay: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct TasteGenreStat: Identifiable {
    let id = UUID()
    let name: String
    let percentage: Double
}

struct TasteDecadeStat: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

struct TasteLanguageStat: Identifiable {
    let id = UUID()
    let language: String
    let percentage: Double
}

struct TasteProfileData {
    let sampleSize: Int
    var avgRating: Double?
    let avgRuntimeMinutes: Int
    let avgPopularity: Int
    
    let versionLabel: String
    let keywordsCount: Int
    let peopleCount: Int
    
    let topGenres: [TasteGenreStat]
    let decades: [TasteDecadeStat]
    let languages: [TasteLanguageStat]
    var rawTopPeopleIds: [Int] = []
}

struct MyProgressStatsData {
    let watchTimeHours: Int
    let episodesWatched: Int
    let moviesWatched: Int
    let showsWatched: Int
    
    let currentStreak: Int
    let bestStreak: Int
    
    let firstPlayTitle: String
    let firstPlayDate: Date
    let lastPlayTitle: String
    let lastPlayDate: Date
    
    let activityMap: [ProgressActivityDay]
    let allActivityMap: [ProgressActivityDay]
    
    let monthlyStats: [ProgressMonthlyStat]
    let timeDistribution: ProgressTimeDistribution
    let busiestDays: [ProgressDayStat]
    
    let topGenres: [ProgressGenreStat]
    let mostWatchedActors: [ProgressPersonStat]
    let mostWatchedDirectors: [ProgressPersonStat]
    
    var tasteData: TasteProfileData
}

extension MyProgressStatsData {
    static var mock: MyProgressStatsData = {
        let calendar = Calendar.current
        let today = Date()
        
        // Generate mock activity
        var activity: [ProgressActivityDay] = []
        for i in 0..<365 {
            if let d = calendar.date(byAdding: .day, value: -i, to: today) {
                let count = Int.random(in: 0...6)
                if count > 0 {
                    activity.append(ProgressActivityDay(date: d, count: count))
                }
            }
        }
        
        let firstPlay = calendar.date(byAdding: .year, value: -2, to: today) ?? today
        let lastPlay = today
        
        let taste = TasteProfileData(
            sampleSize: 25,
            avgRating: nil,
            avgRuntimeMinutes: 94,
            avgPopularity: 61,
            versionLabel: "VERSION 76",
            keywordsCount: 150,
            peopleCount: 400,
            topGenres: [
                TasteGenreStat(name: "Sci-Fi & Fantasy", percentage: 0.12),
                TasteGenreStat(name: "Drama", percentage: 0.12),
                TasteGenreStat(name: "Thriller", percentage: 0.11),
                TasteGenreStat(name: "Action & Adventure", percentage: 0.09),
                TasteGenreStat(name: "Comedy", percentage: 0.08),
                TasteGenreStat(name: "Animation", percentage: 0.08),
                TasteGenreStat(name: "Music", percentage: 0.06),
                TasteGenreStat(name: "Action", percentage: 0.05)
            ],
            decades: [
                TasteDecadeStat(label: "60s", count: 2),
                TasteDecadeStat(label: "70s", count: 8),
                TasteDecadeStat(label: "80s", count: 14),
                TasteDecadeStat(label: "90s", count: 25),
                TasteDecadeStat(label: "00s", count: 42),
                TasteDecadeStat(label: "10s", count: 58),
                TasteDecadeStat(label: "20s", count: 30)
            ],
            languages: [
                TasteLanguageStat(language: "English", percentage: 0.65),
                TasteLanguageStat(language: "Japanese", percentage: 0.15),
                TasteLanguageStat(language: "Korean", percentage: 0.08),
                TasteLanguageStat(language: "Spanish", percentage: 0.05),
                TasteLanguageStat(language: "French", percentage: 0.04),
                TasteLanguageStat(language: "Italian", percentage: 0.02),
                TasteLanguageStat(language: "German", percentage: 0.01)
            ]
        )
        
        return MyProgressStatsData(
            watchTimeHours: 242,
            episodesWatched: 324,
            moviesWatched: 82,
            showsWatched: 25,
            currentStreak: 12,
            bestStreak: 34,
            firstPlayTitle: "The Sopranos",
            firstPlayDate: firstPlay,
            lastPlayTitle: "Dune: Part Two",
            lastPlayDate: lastPlay,
            activityMap: activity,
            allActivityMap: activity,
            monthlyStats: [
                ProgressMonthlyStat(month: "Jul", count: 12),
                ProgressMonthlyStat(month: "Aug", count: 18),
                ProgressMonthlyStat(month: "Sep", count: 5),
                ProgressMonthlyStat(month: "Oct", count: 24),
                ProgressMonthlyStat(month: "Nov", count: 8),
                ProgressMonthlyStat(month: "Dec", count: 15),
                ProgressMonthlyStat(month: "Jan", count: 20),
                ProgressMonthlyStat(month: "Feb", count: 14),
                ProgressMonthlyStat(month: "Mar", count: 22),
                ProgressMonthlyStat(month: "Apr", count: 30),
                ProgressMonthlyStat(month: "May", count: 16),
                ProgressMonthlyStat(month: "Jun", count: 25)
            ],
            timeDistribution: ProgressTimeDistribution(morning: 15, afternoon: 25, evening: 80, night: 40),
            busiestDays: [
                ProgressDayStat(day: "Mon", count: 12),
                ProgressDayStat(day: "Tue", count: 18),
                ProgressDayStat(day: "Wed", count: 24),
                ProgressDayStat(day: "Thu", count: 16),
                ProgressDayStat(day: "Fri", count: 35),
                ProgressDayStat(day: "Sat", count: 55),
                ProgressDayStat(day: "Sun", count: 42)
            ],
            topGenres: [
                ProgressGenreStat(name: "Sci-Fi", count: 42),
                ProgressGenreStat(name: "Drama", count: 38),
                ProgressGenreStat(name: "Action", count: 35),
                ProgressGenreStat(name: "Thriller", count: 28),
                ProgressGenreStat(name: "Comedy", count: 20),
                ProgressGenreStat(name: "Horror", count: 15),
                ProgressGenreStat(name: "Adventure", count: 12),
                ProgressGenreStat(name: "Mystery", count: 9),
                ProgressGenreStat(name: "Romance", count: 6)
            ],
            mostWatchedActors: [
                ProgressPersonStat(name: "Timothée Chalamet", count: 5, profilePath: "/BE2sdjpgsa2rNTFa66f7upkaOPM.jpg", tmdbId: 1190668),
                ProgressPersonStat(name: "Zendaya", count: 4, profilePath: "/soAou4oH8n25vH8PZ7YdE4S49zD.jpg", tmdbId: 1356210),
                ProgressPersonStat(name: "Oscar Isaac", count: 3, profilePath: "/qK6MvQxV224u1tW3J9iJ9l3vA1X.jpg", tmdbId: 3223),
                ProgressPersonStat(name: "Rebecca Ferguson", count: 3, profilePath: "/yZNRXkM14Fm69X2WqfB3F7GgZl3.jpg", tmdbId: 109513),
                ProgressPersonStat(name: "Javier Bardem", count: 2, profilePath: "/9aHl2I81kFtcF0L41tV3w1tT2Q.jpg", tmdbId: 3810),
                ProgressPersonStat(name: "Florence Pugh", count: 2, profilePath: "/rwtv1Bq0Pj1i3fE630Hn0G2lY01.jpg", tmdbId: 1373737),
                ProgressPersonStat(name: "Austin Butler", count: 2, profilePath: "/2kswb6w0u0G98T164k8Z122wQ6B.jpg", tmdbId: 1146861),
                ProgressPersonStat(name: "Josh Brolin", count: 2, profilePath: "/xX2HqRtkZ4EtwGlaM6hGj1k4k8E.jpg", tmdbId: 16828)
            ],
            mostWatchedDirectors: [
                ProgressPersonStat(name: "Denis Villeneuve", count: 4, profilePath: "/xNDdEniS1XmWeWqXbJ8i4Wj0A4P.jpg", tmdbId: 137427),
                ProgressPersonStat(name: "Christopher Nolan", count: 3, profilePath: "/xuAIuYSsl1R6E61qWwI9E710pI1.jpg", tmdbId: 525),
                ProgressPersonStat(name: "Martin Scorsese", count: 2, profilePath: "/9U9Y5GQuWX3EZy39B8nkk4NY01S.jpg", tmdbId: 224),
                ProgressPersonStat(name: "Quentin Tarantino", count: 2, profilePath: "/1gjcpAa99FAOWGzWS5jA1p7pUeW.jpg", tmdbId: 138),
                ProgressPersonStat(name: "David Fincher", count: 2, profilePath: "/3Nf07q9OesjZ1P0E7Y2kU5sF15w.jpg", tmdbId: 1243),
                ProgressPersonStat(name: "Steven Spielberg", count: 2, profilePath: "/tZxcg19YQ3e8fJ0pOs7hjlnmmr6.jpg", tmdbId: 488)
            ],
            tasteData: taste
        )
    }()
}
