import Foundation
import SwiftData
import Testing

@testable import MonMon

/// Amount extraction from real Vietnamese bank notification payloads.
///
/// Every case runs through the real `TransactionCaptureService.prepareNotification`
/// so the parser is exercised exactly as the app calls it. The balance lines are
/// kept in every payload on purpose: the bug this suite guards against is the
/// parser picking up `SD:` (số dư, the balance) instead of the movement.
@MainActor
@Suite("Bank notification amount parsing")
struct BankNotificationParserTests {
    private let now = Date(timeIntervalSince1970: 1_735_776_000)

    // MARK: - Acceptance case reported by the user

    /// TPBank push payload, verbatim from the user's phone. TPBank labels the
    /// movement `PS:` (phát sinh) with the sign glued to the number and `VND`
    /// glued to the digits, then repeats the balance twice as `SD:` and
    /// `SD KHA DUNG:`. The balance 23.457.587 must never win over PS 62.000.
    @Test("TPBank PS line supplies the amount, never the SD balance")
    func tpBankUserPayload() throws {
        let fixture = try makeFixture()
        let text = """
            (TPBank): 16/09/26;20:30
            TK: xxxx3688261
            PS:-62.000VND
            SD: 23.457.587VND
            SD KHA DUNG: 23.457.587VND
            ND: Le Van Son chuyen tien
            SO GD: 669V60026259AAFF
            """
        let capture = try fixture.service.prepareNotification(
            BankNotificationEvent(text: text, source: "TP bank", receivedAt: now),
            accountID: fixture.accountID, automaticSave: true)

        #expect(capture.amount == 62_000)
        #expect(capture.amount != 23_457_587)
        #expect(capture.kind == .expense)
        #expect(!capture.issues.contains(.missingAmount))
        #expect(capture.note == "Le Van Son chuyen tien")
    }

    // MARK: - Per bank payloads

    /// Real-world label and separator conventions per bank:
    ///
    /// - VCB (Vietcombank, VCB Digibank push): pipe separated segments, `GD:`
    ///   label, comma thousands separator, `VND` after a space.
    /// - Techcombank (TCB): pipe separated, `GD:` label, comma thousands, `VND`
    ///   glued to the digits, `+` for credits.
    /// - MB (MBBank): pipe separated with spaces around the pipes, `GD:` label,
    ///   dot thousands separator.
    /// - ACB: multi line, `GD:` label, comma thousands with a `.00` decimal tail.
    /// - BIDV: multi line, `PS:` label, dot thousands with a `,00` decimal tail.
    /// - VPBank: multi line, `So tien:` label, space grouped digits (the app
    ///   emits U+00A0 non breaking spaces), `So du:` for the balance.
    @Test(
        "Each bank's movement label supplies the amount and its sign",
        arguments: [
            (
                "VCB",
                "VCB: TK 0011001234567|GD: -250,000 VND|SD: 12,345,678 VND|ND: THANH TOAN HOA DON",
                Decimal(250_000), TransactionKind.expense
            ),
            (
                "Techcombank",
                "TCB: TK 19031234567890|GD: +1,500,000VND|SD: 5,000,000VND|ND: LUONG THANG 9",
                Decimal(1_500_000), TransactionKind.income
            ),
            (
                "MB",
                "MBBank: TK 0123456789 | GD: -1.234.567 VND | SD: 8.765.432 VND | ND: Mua sam",
                Decimal(1_234_567), TransactionKind.expense
            ),
            (
                "ACB",
                "ACB: 16/09/26 TK 1234567890\nGD: -1,234,567.00 VND\nSD: 2,000,000.00 VND\nND: Hoa don",
                Decimal(1_234_567), TransactionKind.expense
            ),
            (
                "BIDV",
                "BIDV: TK 12010001234567\nPS: -1.234.567,00 VND\nSD: 9.000.000,00 VND\nND: Mua hang",
                Decimal(1_234_567), TransactionKind.expense
            ),
            (
                "VPBank",
                "VPBank: TK 123456789\nSo tien: -50\u{00A0}000 VND\nSo du: 1\u{00A0}200\u{00A0}000 VND\nND: Ca phe",
                Decimal(50_000), TransactionKind.expense
            ),
        ])
    func bankPayloads(
        bank: String, text: String, expected: Decimal, kind: TransactionKind
    ) throws {
        let fixture = try makeFixture()
        let capture = try fixture.service.prepareNotification(
            BankNotificationEvent(text: text, source: bank, receivedAt: now),
            accountID: fixture.accountID, automaticSave: true)

        #expect(capture.amount == expected, "\(bank) amount")
        #expect(capture.kind == kind, "\(bank) kind")
    }

    // MARK: - Number formats

    @Test(
        "Thousand and decimal separators normalize to one amount",
        arguments: [
            ("GD: -1.234.567 VND", Decimal(1_234_567)),
            ("GD: -1,234,567 VND", Decimal(1_234_567)),
            ("GD: -1,234,567.00 VND", Decimal(1_234_567)),
            ("GD: -1.234.567,00 VND", Decimal(1_234_567)),
            ("GD: -50\u{00A0}000 VND", Decimal(50_000)),
            ("GD: -50 000 VND", Decimal(50_000)),
            ("GD: -62000 VND", Decimal(62_000)),
        ])
    func numberFormats(text: String, expected: Decimal) throws {
        let fixture = try makeFixture()
        let capture = try fixture.service.prepareNotification(
            BankNotificationEvent(text: text, source: "Bank", receivedAt: now),
            accountID: fixture.accountID, automaticSave: true)
        #expect(capture.amount == expected)
    }

    // MARK: - Currency suffixes and terminators

    @Test(
        "Currency suffixes and sentence terminators do not block the amount",
        arguments: [
            "GD: -62.000VND", "GD: -62.000VNĐ", "GD: -62.000đ", "GD: -62.000Đ",
            "GD: -62.000vnd", "GD: -62.000 VND.", "GD: -62.000VND)",
            "TK 0123456789|GD: -62.000VND|SD: 1.000.000VND",
            "GD: -62.000 VND; SD: 1.000.000 VND",
        ])
    func currencySuffixes(text: String) throws {
        let fixture = try makeFixture()
        let capture = try fixture.service.prepareNotification(
            BankNotificationEvent(text: text, source: "Bank", receivedAt: now),
            accountID: fixture.accountID, automaticSave: true)
        #expect(capture.amount == 62_000)
        #expect(capture.kind == .expense)
    }

    @Test("An unsigned movement still yields an amount and defaults to expense")
    func unsignedMovement() throws {
        let fixture = try makeFixture()
        let capture = try fixture.service.prepareNotification(
            BankNotificationEvent(
                text: "GD: 62.000 VND\nSD: 1.000.000 VND", source: "Bank", receivedAt: now),
            accountID: fixture.accountID, automaticSave: true)
        #expect(capture.amount == 62_000)
        #expect(capture.kind == .expense)
    }

    // MARK: - Negative cases

    /// Balance only, account number only and authentication payloads carry no
    /// movement. Taking a number from them would book a transaction that never
    /// happened, so they must stay flagged as missing an amount.
    @Test(
        "Payloads without a movement never yield an amount",
        arguments: [
            "SD: 23.457.587VND",
            "So du: 1,000,000 VND",
            "SD KHA DUNG: 23.457.587VND",
            "TK: xxxx3688261",
            "TK 0011001234567",
            "OTP 123456 xac thuc giao dich tai ngan hang",
            "Ma OTP cua quy khach la 987654, hieu luc 3 phut.",
        ])
    func payloadsWithoutMovement(text: String) throws {
        let fixture = try makeFixture()
        let capture = try fixture.service.prepareNotification(
            BankNotificationEvent(text: text, source: "Bank", receivedAt: now),
            accountID: fixture.accountID, automaticSave: true)
        #expect(capture.amount == nil)
        #expect(capture.issues.contains(.missingAmount))
        #expect(!capture.isReady)
    }

    // MARK: - Fixture

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let accountID = UUID()
        let categoryID = UUID()
        let incomeCategoryID = UUID()
        context.insert(
            CashAccount(
                id: accountID,
                name: "TPBank",
                kind: .normal,
                openingBalance: 0,
                currencyCode: VNDCurrency.code,
                createdAt: now
            )
        )
        context.insert(
            TransactionCategory(
                id: categoryID,
                name: "Ăn uống",
                kind: .expense,
                symbolName: "fork.knife",
                colorName: "peach",
                createdAt: now
            )
        )
        context.insert(
            TransactionCategory(
                id: incomeCategoryID,
                name: "Lương",
                kind: .income,
                symbolName: "banknote.fill",
                colorName: "green",
                createdAt: now.addingTimeInterval(1)
            )
        )
        try context.save()

        let suiteName = "BankNotificationParserTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(accountID.uuidString, forKey: TransactionDefaults.accountStorageKey)
        defaults.set(categoryID.uuidString, forKey: TransactionDefaults.categoryStorageKey)

        return Fixture(
            container: container,
            service: TransactionCaptureService(container: container, defaults: defaults),
            accountID: accountID
        )
    }

    private struct Fixture {
        let container: ModelContainer
        let service: TransactionCaptureService
        let accountID: UUID
    }
}
