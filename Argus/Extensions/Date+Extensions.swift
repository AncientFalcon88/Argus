import Foundation

extension Date {
    static func parseRobustly(_ dateString: String?) -> Date {
        guard let dateString = dateString, !dateString.isEmpty else { return Date(timeIntervalSince1970: 0) }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) { return date }
        
        // Clean up common backend anomalies (missing Z, spaces instead of T, microsecond precision)
        var fixedString = dateString
        fixedString = fixedString.replacingOccurrences(of: " ", with: "T")
        
        // Append Z if missing, assuming backend is returning UTC
        let timePart = fixedString.dropFirst(10)
        if !fixedString.hasSuffix("Z") && !timePart.contains("+") && !timePart.contains("-") {
            fixedString += "Z"
        }
        
        // Trim microseconds to milliseconds for Swift compatibility
        if let dotIndex = fixedString.lastIndex(of: ".") {
            let zIndex = fixedString.lastIndex(of: "Z") ?? fixedString.endIndex
            let fraction = fixedString[fixedString.index(after: dotIndex)..<zIndex]
            if fraction.count > 3 {
                let trimmedFraction = fraction.prefix(3)
                fixedString.replaceSubrange(fraction.startIndex..<fraction.endIndex, with: trimmedFraction)
            }
        }
        
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: fixedString) { return date }
        
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: fixedString) { return date }
        
        let simpleFormatter = DateFormatter()
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        simpleFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        if let date = simpleFormatter.date(from: dateString) { return date }
        
        return Date(timeIntervalSince1970: 0)
    }
}

extension String {
    func formattedLocalTime(includeDay: Bool = false) -> String {
        let date = Date.parseRobustly(self)
        if date <= Date(timeIntervalSince1970: 0) {
            return self // Fallback to raw string if parsing genuinely failed
        }
        let formatter = DateFormatter()
        formatter.dateFormat = includeDay ? "EEE, yyyy-MM-dd • HH:mm" : "yyyy-MM-dd • HH:mm"
        return formatter.string(from: date)
    }
}
