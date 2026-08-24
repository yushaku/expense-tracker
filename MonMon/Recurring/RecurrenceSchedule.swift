import Foundation

/// When a recurring rule falls due.
///
/// Pure maths on plain values: nothing here touches SwiftData and nothing reads
/// the clock, so a schedule is reproducible and testable. The calendar is the
/// one `TransactionPeriod` already shares, so no module depends on the machine's
/// locale or time zone.
///
/// ## Why every occurrence is measured from the anchor
///
/// Each date is `anchor + step × interval` units, never "the last occurrence
/// plus one interval". Stepping off the previous date accumulates drift the
/// moment a month is too short: a rule anchored on 31 January would go
/// 31 January, 28 February, 28 March, and lose the 31st for good. Measuring from
/// the anchor clamps February and comes straight back to the 31st in March.
enum RecurrenceSchedule {
    /// A pathological rule — daily, anchored decades back — would otherwise spin
    /// here while skipping dates it has already generated. Well above any real
    /// schedule, low enough to stay a loop and not a hang.
    static let maxSteps = 100_000

    static var calendar: Calendar {
        TransactionPeriod.calendar
    }

    /// The `step`-th occurrence, counting the anchor itself as step zero.
    /// Returns `nil` for an interval below one, which validation rejects before
    /// a rule is ever written.
    static func occurrence(
        frequency: RecurrenceFrequency,
        interval: Int,
        anchor: Date,
        step: Int
    ) -> Date? {
        guard interval >= 1, step >= 0 else {
            return nil
        }

        let start = calendar.startOfDay(for: anchor)
        guard step > 0 else {
            return start
        }

        return calendar.date(
            byAdding: frequency.component,
            value: step * interval * frequency.componentsPerStep,
            to: start
        )
    }

    /// Every occurrence in `(after, through]`, oldest first.
    ///
    /// - Parameters:
    ///   - after: exclusive lower bound, normally the newest date already
    ///     generated. `nil` starts at the anchor.
    ///   - through: inclusive upper bound. Always passed in — a generator that
    ///     read the clock here could not be tested.
    ///   - limit: the most dates to return, so one rule can never write an
    ///     unbounded number of transactions in a single pass.
    static func occurrences(
        frequency: RecurrenceFrequency,
        interval: Int,
        anchor: Date,
        after: Date?,
        through: Date,
        limit: Int
    ) -> [Date] {
        guard interval >= 1, limit > 0 else {
            return []
        }

        let end = calendar.startOfDay(for: through)
        let floor = after.map { calendar.startOfDay(for: $0) }

        var dates: [Date] = []
        var step = 0

        while dates.count < limit, step < maxSteps {
            guard
                let date = occurrence(
                    frequency: frequency,
                    interval: interval,
                    anchor: anchor,
                    step: step
                )
            else {
                break
            }

            if date > end {
                break
            }

            step += 1

            if let floor, date <= floor {
                continue
            }

            dates.append(date)
        }

        return dates
    }

    /// The first occurrence strictly after `after`, with no upper bound. What a
    /// card shows as "next due"; an end date is the caller's to apply.
    static func nextOccurrence(
        frequency: RecurrenceFrequency,
        interval: Int,
        anchor: Date,
        after: Date
    ) -> Date? {
        guard interval >= 1 else {
            return nil
        }

        let floor = calendar.startOfDay(for: after)
        var step = 0

        while step < maxSteps {
            guard
                let date = occurrence(
                    frequency: frequency,
                    interval: interval,
                    anchor: anchor,
                    step: step
                )
            else {
                return nil
            }

            if date > floor {
                return date
            }

            step += 1
        }

        return nil
    }
}
