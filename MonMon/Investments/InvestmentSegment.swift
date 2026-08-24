import Foundation
import SwiftUI

/// Which half of the Investments screen is showing. Savings books and fund
/// holdings are the same idea — money parked rather than spent — so they share
/// one tab and take turns behind this picker.
enum InvestmentSegment: String, CaseIterable, Identifiable, Hashable {
    case savings
    case funds
    case gold

    var id: String {
        rawValue
    }

    var displayName: LocalizedStringKey {
        switch self {
        case .savings:
            "Savings"
        case .funds:
            "Funds"
        case .gold:
            "Gold"
        }
    }

    /// The add button changes with the segment rather than offering a menu, so
    /// adding stays one tap from whichever list is already in front of you.
    var addTitle: LocalizedStringKey {
        switch self {
        case .savings:
            "Add Savings Book"
        case .funds:
            "Add Holding"
        case .gold:
            "Add Gold"
        }
    }

    /// Kept from the two screens this one replaces, so anything already reaching
    /// for these buttons still finds them.
    var addIdentifier: String {
        switch self {
        case .savings:
            "add-savings"
        case .funds:
            "add-fund"
        case .gold:
            "add-gold"
        }
    }
}
