import Foundation
import SwiftUI

/// Converts the owner-facing chỉ quantity into the canonical stored lượng.
enum GoldWeight {
    static let chiPerLuong: Decimal = 10

    static func parseChi(_ text: String) -> Decimal? {
        UnitQuantity.parse(text).map { $0 / chiPerLuong }
    }

    static func formatChi(luong: Decimal) -> String {
        UnitQuantity.format(luong * chiPerLuong)
    }

    static func label(luong: Decimal) -> String {
        "\(formatChi(luong: luong)) chỉ (\(UnitQuantity.format(luong)) lượng)"
    }
}

/// Which of gold's two units a form is typing in.
///
/// The store keeps lượng, always. What this decides is the unit the owner
/// works in, and it moves the weight and the price together: a weight in chỉ
/// beside a price per lượng is two numbers a factor of ten apart with nothing
/// on screen saying so, which reads as a purchase ten times the size of the
/// one being recorded.
///
/// Chỉ is the default because it is the amount gold is actually bought in.
enum GoldUnit: String, CaseIterable, Identifiable, Sendable {
    case chi
    case luong

    var id: String { rawValue }

    /// How many of this unit make one stored lượng. The weight typed is
    /// divided by it and the price typed is multiplied by it, so the two always
    /// describe the same purchase.
    var perLuong: Decimal {
        switch self {
        case .chi:
            GoldWeight.chiPerLuong
        case .luong:
            1
        }
    }

    var displayNameKey: String {
        switch self {
        case .chi:
            "chỉ"
        case .luong:
            "lượng"
        }
    }

    var displayName: LocalizedStringKey {
        LocalizedStringKey(displayNameKey)
    }
}
