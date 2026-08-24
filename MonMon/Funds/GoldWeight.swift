import Foundation

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
