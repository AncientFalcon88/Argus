import SwiftUI
import Charts

enum ActivityTimeframe: String, CaseIterable {
    case days = "Days"
    case weeks = "Weeks"
    case months = "Months"
    case years = "Years"
}

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let activity: [ProgressActivityDay]
    let selectedYear: String
    
    @State private var selectedTimeframe: ActivityTimeframe = .days
    
    private var availableTimeframes: [ActivityTimeframe] {
        if selectedYear == "ALL TIME" {
            return ActivityTimeframe.allCases
        } else {
            return [.days, .weeks, .months]
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                VStack(spacing: 24) {
                    GlassTabSelector(selection: $selectedTimeframe, options: availableTimeframes) { frame in
                        frame.rawValue
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    VStack(spacing: 24) {
                        GlassCard(title: "Watch History") {
                            Chart {
                                ForEach(aggregatedData) { item in
                                    AreaMark(
                                        x: .value("Time", item.label),
                                        y: .value("Count", item.count)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green.opacity(0.6), .green.opacity(0.0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    
                                    LineMark(
                                        x: .value("Time", item.label),
                                        y: .value("Count", item.count)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.green)
                                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                                    
                                    PointMark(
                                        x: .value("Time", item.label),
                                        y: .value("Count", item.count)
                                    )
                                    .foregroundStyle(.white)
                                    .symbolSize(40)
                                }
                            }
                            .chartScrollableAxes(.horizontal)
                            .chartXVisibleDomain(length: max(1, min(aggregatedData.count, 5)))
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                                    if let label = value.as(String.self) {
                                        AxisValueLabel {
                                            Text(label)
                                                .foregroundStyle(.secondary)
                                                .font(.caption2)
                                                .lineLimit(1)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                                    AxisValueLabel() {
                                        if let count = value.as(Int.self) {
                                            Text("\(count) titles")
                                                .foregroundStyle(.secondary)
                                                .font(.caption2)
                                                .lineLimit(1)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Activity History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                }
            }
        }
    }
    
    struct AggregatedItem: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
    }
    
    private var aggregatedData: [AggregatedItem] {
        let calendar = Calendar.current
        var dict: [Date: Int] = [:]
        
        var minDate: Date?
        var maxDate: Date?
        
        for act in activity {
            let startOfPeriod: Date
            switch selectedTimeframe {
            case .days:
                startOfPeriod = calendar.startOfDay(for: act.date)
            case .weeks:
                let comp = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: act.date)
                startOfPeriod = calendar.date(from: comp) ?? act.date
            case .months:
                let comp = calendar.dateComponents([.year, .month], from: act.date)
                startOfPeriod = calendar.date(from: comp) ?? act.date
            case .years:
                let comp = calendar.dateComponents([.year], from: act.date)
                startOfPeriod = calendar.date(from: comp) ?? act.date
            }
            dict[startOfPeriod, default: 0] += act.count
            
            if minDate == nil || startOfPeriod < minDate! { minDate = startOfPeriod }
            if maxDate == nil || startOfPeriod > maxDate! { maxDate = startOfPeriod }
        }
        
        guard var start = minDate, var end = maxDate else { return [] }
        
        // Fix single-point clipping and math by injecting dummy zeros
        if start == end {
            let component: Calendar.Component
            switch selectedTimeframe {
            case .days: component = .day
            case .weeks: component = .weekOfYear
            case .months: component = .month
            case .years: component = .year
            }
            if let prev = calendar.date(byAdding: component, value: -1, to: start) {
                dict[prev] = 0
                start = prev
            }
            if let next = calendar.date(byAdding: component, value: 1, to: end) {
                dict[next] = 0
                end = next
            }
        }
        
        // Zero-fill all gaps
        var current = start
        while current <= end {
            if dict[current] == nil {
                dict[current] = 0
            }
            let component: Calendar.Component
            switch selectedTimeframe {
            case .days: component = .day
            case .weeks: component = .weekOfYear
            case .months: component = .month
            case .years: component = .year
            }
            current = calendar.date(byAdding: component, value: 1, to: current)!
        }
        
        let sortedKeys = dict.keys.sorted()
        return sortedKeys.map { date in
            let label: String
            switch selectedTimeframe {
            case .days:
                label = date.formatted(.dateTime.month(.abbreviated).day())
            case .weeks:
                label = date.formatted(.dateTime.month(.abbreviated).day())
            case .months:
                label = date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
            case .years:
                label = date.formatted(.dateTime.year())
            }
            return AggregatedItem(label: label, count: dict[date]!)
        }
    }
}
