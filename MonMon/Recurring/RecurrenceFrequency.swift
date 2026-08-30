import Foundation
import SwiftUI

/// How often a recurring rule stamps out a transaction.
///
/// Shaped like `TransactionKind`: a `String` raw value that is never renamed,
/// because the store keeps it. The `Calendar` arithmetic lives here rather than
/// in `RecurrenceSchedule` so adding a frequency is one case, not two.
enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String {
        rawValue
    }

    var displayNameKey: String {
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

    var displayName: LocalizedStringKey {
        LocalizedStringKey(displayNameKey)
    }

    func displayName(in locale: Locale) -> String {
        AppText.string(key: displayNameKey, in: locale)
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

    /// Reads inside a sentence: "Every month", "Every 2 weeks". Each case is a
    /// whole phrase rather than a unit with an "s" stuck on the end, because how
    /// a language counts is its own business — Vietnamese does not change the
    /// word at all.
    func phrase(interval: Int, in locale: Locale) -> String {
        guard interval > 1 else {
            switch self {
            case .daily:
                return AppText.string("Every day", in: locale)
            case .weekly:
                return AppText.string("Every week", in: locale)
            case .monthly:
                return AppText.string("Every month", in: locale)
            case .yearly:
                return AppText.string("Every year", in: locale)
            }
        }

        switch self {
        case .daily:
            return AppText.string("Every \(interval) days", in: locale)
        case .weekly:
            return AppText.string("Every \(interval) weeks", in: locale)
        case .monthly:
            return AppText.string("Every \(interval) months", in: locale)
        case .yearly:
            return AppText.string("Every \(interval) years", in: locale)
        }
    }
}
