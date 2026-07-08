import Foundation

/// "Today" boundaries are computed in Asia/Bangkok, never device UTC (see plan risk #3).
public enum BangkokDate {
    public static let timeZone = TimeZone(identifier: "Asia/Bangkok")!

    private static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Current date as `YYYY-MM-DD` in Asia/Bangkok — used to prefill transaction dates.
    public static func todayString(now: Date = Date()) -> String {
        ymd.string(from: now)
    }

    public static func string(from date: Date) -> String { ymd.string(from: date) }
    public static func date(from string: String) -> Date? { ymd.date(from: string) }
}
