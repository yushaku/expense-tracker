import Foundation

/// How often a recurring rule stamps out a transaction.
///
/// Shaped like `TransactionKind`: a `String` raw value that is never renamed,
/// because the store keeps it. The `Calendar` arithmetic lives here rather than
/// in `RecurrenceSchedule` so adding a frequency is one case, not two.
enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .daily:
            "Daily"
        case .weekly:
            "Weekly"
        case .monthly:
            "Monthly"
        case .yearly:
            "Yearly"
        }
    }

    var symbolName: String {
        switch self {
        case .daily:
            "sun.max.fill"
        case .weekly:
            "calendar.day.timeline.left"
        case .monthly:
            "calendar"
        case .yearly:
            "calendar.badge.clock"
        }
    }

    /// The unit a step is added in. A week is seven days rather than
    /// `.weekOfYear`, so every frequency lands on the anchor's own weekday
    /// without depending on which day the calendar considers a week to start on.
    var component: Calendar.Component {
        switch self {
        case .daily, .weekly:
            .day
        case .monthly:
            .month
        case .yearly:
            .year
        }
    }

    /// How many of `component` one step of this frequency covers.
    var componentsPerStep: Int {
        self == .weekly ? 7 : 1
    }

    /// Reads inside a sentence: "Every month", "Every 2 weeks".
    func phrase(interval: Int) -> String {
        guard interval > 1 else {
            return "Every \(singularUnit)"
        }

        return "Every \(interval) \(singularUnit)s"
    }

    private var singularUnit: String {
        switch self {
        case .daily:
            "day"
        case .weekly:
            "week"
        case .monthly:
            "month"
        case .yearly:
            "year"
        }
    }
}
