import Foundation

/// The newest day each market can cover, and whether a stored price is older.
///
/// Built on the calendar `TransactionPeriod` already shares (Gregorian,
/// `Asia/Ho_Chi_Minh`) rather than a second one, so no module reads the
/// machine's locale or time zone. Every function takes the date it needs;
/// nothing reads the clock, so tests are deterministic.
///
/// Public holidays are **not** modelled. A Tết week reports every price as
/// stale, which is honest about what the app knows and better than a hardcoded
/// holiday table quietly going wrong in a later year.
enum TradingCalendar {
    /// HOSE trades 09:00–15:00 on weekdays.
    static let sessionCloseHour = 15

    /// How old a coin price may be before it counts as stale.
    ///
    /// Crypto has no session to close, so its freshness is a clock question
    /// rather than a calendar one. Fifteen minutes matches
    /// `FundPriceRefresher.requestFloor`, so a screen opened twice inside the
    /// floor finds nothing stale and asks for nothing — the two limits would
    /// otherwise disagree about whether a fetch was worth making.
    static let cryptoStaleWindow: TimeInterval = 15 * 60

    static var calendar: Calendar {
        TransactionPeriod.calendar
    }

    static func isTradingDay(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        // 1 is Sunday and 7 is Saturday in a Gregorian calendar.
        return weekday != 1 && weekday != 7
    }

    /// The most recent day whose session has finished. Before 15:00 that is the
    /// previous weekday; from 15:00 it is today, when today is a weekday.
    static func lastCompletedTradingDay(asOf: Date) -> Date {
        let startOfToday = calendar.startOfDay(for: asOf)
        let closedToday =
            isTradingDay(asOf)
            && calendar.component(.hour, from: asOf) >= sessionCloseHour

        return closedToday ? startOfToday : previousTradingDay(before: startOfToday)
    }

    static func previousTradingDay(before day: Date) -> Date {
        var candidate = day
        for _ in 0..<7 {
            guard let earlier = calendar.date(byAdding: .day, value: -1, to: candidate) else {
                return candidate
            }
            candidate = earlier
            if isTradingDay(candidate) {
                return candidate
            }
        }
        return candidate
    }

    /// A price is current when it is dated on or after the newest day it could
    /// possibly cover.
    ///
    /// An open-ended fund gets one extra trading day of grace: Fmarket publishes
    /// NAV at T+1, so a fund priced at the day before last is as fresh as it can
    /// be, not stale.
    ///
    /// Crypto is compared to the minute instead. Rounding it down to the start
    /// of a day would call a price taken at one minute past midnight current
    /// until the next midnight, which for a market that never closes is a whole
    /// day of saying something false.
    static func isStale(priceAsOf: Date, kind: FundInstrumentKind, asOf: Date) -> Bool {
        let freshest = freshestExpected(kind: kind, asOf: asOf)

        guard kind != .crypto else {
            return priceAsOf < freshest
        }

        return priceAsOf < calendar.startOfDay(for: freshest)
    }

    /// The oldest moment a current price is allowed to carry. Every kind but
    /// crypto answers with a day, which `isStale` then rounds down.
    static func freshestExpected(kind: FundInstrumentKind, asOf: Date) -> Date {
        switch kind {
        case .crypto:
            return asOf.addingTimeInterval(-cryptoStaleWindow)
        case .gold:
            return calendar.startOfDay(for: asOf)
        case .etf:
            return lastCompletedTradingDay(asOf: asOf)
        case .fund:
            return previousTradingDay(before: lastCompletedTradingDay(asOf: asOf))
        }
    }
}
