import Foundation

/// The date wording used on keepsakes.
enum DateText {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = format
        return formatter
    }

    private static let dayMonth = formatter("d MMMM")
    private static let filmFormat = formatter("dd MMM yy")
    private static let dayOnly = formatter("d")
    private static let dayShortMonth = formatter("d MMM")
    private static let weekday = formatter("EEEE")
    private static let monthName = formatter("MMMM")
    private static let yearOnly = formatter("yyyy")

    /// "9 November"
    static func card(_ date: Date?) -> String {
        date.map { dayMonth.string(from: $0) } ?? ""
    }

    /// "09 NOV 26"
    static func filmStamp(_ date: Date?) -> String {
        date.map { filmFormat.string(from: $0).uppercased() } ?? ""
    }

    /// "2026"
    static func year(_ date: Date?) -> String {
        date.map { yearOnly.string(from: $0) } ?? ""
    }

    /// "9–12 NOV", "9 NOV", or "28 OCT – 3 NOV"
    static func range(_ dates: [Date]) -> String {
        guard let first = dates.min(), let last = dates.max() else { return "" }
        let calendar = Calendar.current
        if calendar.isDate(first, inSameDayAs: last) {
            return dayShortMonth.string(from: first).uppercased()
        }
        if calendar.isDate(first, equalTo: last, toGranularity: .month) {
            return "\(dayOnly.string(from: first))–\(dayShortMonth.string(from: last))".uppercased()
        }
        return "\(dayShortMonth.string(from: first)) – \(dayShortMonth.string(from: last))".uppercased()
    }

    /// A short title for a set of photos, based on how far apart they were taken.
    static func title(for dates: [Date]) -> String {
        guard let first = dates.min(), let last = dates.max() else { return "Lately" }
        let calendar = Calendar.current
        if calendar.isDate(first, inSameDayAs: last) {
            return weekday.string(from: first)
        }
        let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
        if days < 7 {
            let recent = (calendar.dateComponents([.day], from: last, to: Date()).day ?? 99) < 7
            return recent ? "This week" : "That week"
        }
        if calendar.isDate(first, equalTo: last, toGranularity: .month) {
            return monthName.string(from: first)
        }
        if calendar.isDate(first, equalTo: last, toGranularity: .year) {
            return yearOnly.string(from: first)
        }
        return "Over time"
    }
}
