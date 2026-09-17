import Foundation
import SwiftData
import Testing

@testable import MonMon

@MainActor
@Suite("Transaction capture persistence")
struct TransactionCaptureServiceTests {
    private let now = Date(timeIntervalSince1970: 1_735_776_000)

    @Test("A ready capture creates one transaction and no pending item")
    func readyCaptureCreatesTransaction() throws {
        let fixture = try makeFixture()
        let prepared = try fixture.service.prepare("50k ăn trưa", now: now)

        let result = try fixture.service.commit(prepared, id: UUID(), createdAt: now)
        let context = ModelContext(fixture.container)
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let pending = try context.fetch(FetchDescriptor<PendingTransactionCapture>())

        #expect(result.disposition == .transaction)
        #expect(transactions.count == 1)
        #expect(transactions.first?.amount == 50_000)
        #expect(transactions.first?.accountID == fixture.accountID)
        #expect(transactions.first?.categoryID == fixture.categoryID)
        #expect(pending.isEmpty)
    }

    @Test("A ready income captures its current jar allocation")
    func readyIncomeCapturesAllocation() throws {
        let fixture = try makeFixture()
        let capture = ParsedTransactionCapture(
            rawText: "Lương 5 triệu",
            kind: .income,
            amount: 5_000_000,
            occurredAt: now,
            note: "Lương",
            accountID: fixture.accountID,
            categoryID: fixture.incomeCategoryID,
            issues: []
        )

        let result = try fixture.service.commit(capture, createdAt: now)
        let context = ModelContext(fixture.container)
        let transaction = try #require(
            context.fetch(FetchDescriptor<MoneyTransaction>()).first
        )

        #expect(result.disposition == .transaction)
        #expect(
            try IncomeAllocationLifecycle.snapshot(in: transaction)?.allocatedAmount == 5_000_000
        )
    }

    @Test("An uncertain capture is staged without changing financial records")
    func uncertainCaptureIsStaged() throws {
        let fixture = try makeFixture()
        let prepared = try fixture.service.prepare("ăn trưa tiền mặt", now: now)

        let result = try fixture.service.commit(prepared, id: UUID(), createdAt: now)
        let context = ModelContext(fixture.container)
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let pending = try context.fetch(FetchDescriptor<PendingTransactionCapture>())

        #expect(result.disposition == .pendingReview)
        #expect(transactions.isEmpty)
        #expect(pending.count == 1)
        #expect(pending.first?.rawText == "ăn trưa tiền mặt")
        #expect(pending.first?.issues.contains(.missingAmount) == true)
    }

    @Test("The intent commits a ready entry in one step")
    func intentCommitsReadyEntryImmediately() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )

        let result = try await dependency.record("50k ăn trưa")
        let context = ModelContext(fixture.container)

        #expect(result.disposition == .transaction)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
    }

    @Test("The intent stages an uncertain entry in one step")
    func intentStagesUncertainEntryImmediately() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )

        let result = try await dependency.record("ăn trưa tiền mặt")
        let context = ModelContext(fixture.container)

        #expect(result.disposition == .pendingReview)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).count == 1)
    }

    @Test("Ready-only intent capture commits one expense without staging review")
    func readyOnlyIntentCommitsExpense() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )

        let result = try await dependency.recordReady("35.000 ☕")
        let context = ModelContext(fixture.container)
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())

        #expect(result.disposition == .transaction)
        #expect(transactions.count == 1)
        #expect(transactions.first?.kind == .expense)
        #expect(transactions.first?.amount == 35_000)
        #expect(transactions.first?.note == "☕")
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
    }

    @Test("Ready-only intent capture writes nothing when defaults are unavailable")
    func readyOnlyIntentRejectsMissingDefaults() async throws {
        let fixture = try makeFixture()
        fixture.defaults.removeObject(forKey: TransactionDefaults.accountStorageKey)
        fixture.defaults.removeObject(forKey: TransactionDefaults.categoryStorageKey)
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )

        await #expect(throws: TransactionCaptureServiceError.incompleteCapture) {
            try await dependency.recordReady("35.000 ☕")
        }

        let context = ModelContext(fixture.container)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
    }

    @Test("Quick expense uses its configured category instead of the global default")
    func quickExpenseUsesConfiguredCategory() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )
        let preset = try QuickExpensePreset(
            slot: .fuel,
            symbol: "⛽",
            amount: 100_000,
            categoryID: fixture.transportCategoryID
        )

        let result = try await dependency.recordQuickExpense(preset)

        let context = ModelContext(fixture.container)
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        #expect(result.disposition == .transaction)
        #expect(transactions.count == 1)
        #expect(transactions.first?.amount == 100_000)
        #expect(transactions.first?.categoryID == fixture.transportCategoryID)
        #expect(transactions.first?.accountID == fixture.accountID)
        #expect(transactions.first?.note == "⛽")
    }

    @Test("Legacy quick expense without a category uses the global default")
    func quickExpenseWithoutCategoryUsesDefault() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )
        let preset = try QuickExpensePreset(
            slot: .coffee,
            symbol: "☕",
            amount: 35_000
        )

        _ = try await dependency.recordQuickExpense(preset)

        let context = ModelContext(fixture.container)
        let transaction = try #require(
            context.fetch(FetchDescriptor<MoneyTransaction>()).first
        )
        #expect(transaction.categoryID == fixture.categoryID)
    }

    @Test("Quick expense rejects a deleted configured category without writing")
    func quickExpenseRejectsDeletedCategory() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )
        let preset = try QuickExpensePreset(
            slot: .coffee,
            symbol: "☕",
            amount: 35_000,
            categoryID: UUID()
        )

        await #expect(throws: TransactionCaptureServiceError.incompleteCapture) {
            try await dependency.recordQuickExpense(preset)
        }

        let context = ModelContext(fixture.container)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
    }

    @Test("Quick expense rejects a configured income category without writing")
    func quickExpenseRejectsIncomeCategory() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )
        let preset = try QuickExpensePreset(
            slot: .coffee,
            symbol: "☕",
            amount: 35_000,
            categoryID: fixture.incomeCategoryID
        )

        await #expect(throws: TransactionCaptureServiceError.incompleteCapture) {
            try await dependency.recordQuickExpense(preset)
        }

        let context = ModelContext(fixture.container)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
    }

    @Test("A stale prepared capture is rejected before writing")
    func stalePreparedCaptureIsRejected() throws {
        let fixture = try makeFixture()
        let prepared = try fixture.service.prepare("50k ăn trưa", now: now)
        let context = ModelContext(fixture.container)
        let accounts = try context.fetch(FetchDescriptor<CashAccount>())
        for account in accounts {
            context.delete(account)
        }
        try context.save()

        #expect(throws: TransactionCaptureServiceError.staleCapture) {
            try fixture.service.commit(prepared, id: UUID(), createdAt: now)
        }
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
    }

    @Test("Notification parser reads a labelled movement, not its balance or account number")
    func notificationRecognizesMovement() throws {
        let fixture = try makeFixture()
        let event = BankNotificationEvent(
            text: "GD: -50.000 VND; TK 0123456789; SD: 9.950.000 VND", source: "Bank",
            receivedAt: now)
        let capture = try fixture.service.prepareNotification(
            event, accountID: fixture.accountID, automaticSave: true)
        #expect(capture.isReady)
        #expect(capture.amount == 50_000)
        #expect(capture.kind == .expense)
        #expect(capture.occurredAt == now)
        #expect(capture.note == event.note)
        #expect(capture.categoryID == fixture.categoryID)
    }

    @Test("TPBank notification keeps only ND as its note and preserves the original for review")
    func notificationExtractsTPBankNote() throws {
        let fixture = try makeFixture()
        let text = """
            (TPBank): 15/09/26;16:00
            TK: xxxx1234567
            PS:-100.000VND
            SD: 23.841.587VND
            SD KHA DUNG: 23.841.587VND
            ND: Le Van Son chuyen tien zalo
            SO GD: TEST123456789
            """
        let event = BankNotificationEvent(text: text, source: "TP bank", receivedAt: now)
        let result = try fixture.service.recordNotification(event, accountID: fixture.accountID)
        let context = ModelContext(fixture.container)
        let pending = try #require(
            context.fetch(FetchDescriptor<PendingTransactionCapture>()).first)

        #expect(result.result.disposition == .pendingReview)
        #expect(pending.note == "Le Van Son chuyen tien zalo")
        #expect(pending.rawText == "[TP bank]\n\(text)")
        #expect(pending.issues.contains(.missingAmount) == false)
        #expect(pending.amount == 100_000)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        #expect(
            try fixture.service.recordNotification(event, accountID: fixture.accountID).duplicate)
    }

    @Test(
        "Extracted notification notes preserve accents and support line endings",
        arguments: ["\n", "\r\n", "\r"])
    func notificationNoteLineEndings(newline: String) throws {
        let fixture = try makeFixture()
        fixture.defaults.set(true, forKey: BankNotificationPreferences.automaticSaveKey)
        let text = ["GD: -100.000 VND", "  ND:\tĂn trưa 🍜  ", "SO GD: TEST123"].joined(
            separator: newline)
        let event = BankNotificationEvent(text: text, source: "Bank", receivedAt: now)
        let capture = try fixture.service.prepareNotification(
            event, accountID: fixture.accountID, automaticSave: true)
        #expect(capture.note == "Ăn trưa 🍜")
        #expect(capture.rawText == "[Bank]\n\(text)")
        #expect(capture.amount == 100_000)
        let result = try fixture.service.recordNotification(event, accountID: fixture.accountID)
        #expect(result.result.disposition == .transaction)
        let transaction = try #require(
            ModelContext(fixture.container).fetch(FetchDescriptor<MoneyTransaction>()).first)
        #expect(transaction.note == "Ăn trưa 🍜")
    }

    @Test(
        "Missing, empty or ambiguous ND fields retain the original notification note",
        arguments: [
            "GD: -100.000 VND", "ND: \nSO GD: TEST123", "ND:\nND: Lunch",
            "ND: Lunch\nND: Dinner", "REFERENCE ND: Lunch", "ND KHAC: Lunch",
        ])
    func notificationNoteFallback(text: String) throws {
        let fixture = try makeFixture()
        let capture = try fixture.service.prepareNotification(
            BankNotificationEvent(text: text, source: " Bank ", receivedAt: now),
            accountID: fixture.accountID)
        #expect(capture.note == "[Bank]\n\(text)")
        #expect(capture.rawText == "[Bank]\n\(text)")
    }

    @Test(
        "Unknown and unsafe bank notifications never auto-save",
        arguments: [
            "SD: +1.000.000 VND", "OTP 123456", "50k ăn trưa",
            "GD: -0 VND", "GD: -50.000 USD", "GD: -50.000 VND; giao dịch thất bại",
            "GD: +50.000 VND; chuyển tiền", "GD: -50.000 VND; pending",
            "GD: -50.000 VND; GD: -60.000 VND", "GD: -999999999999999999 VND",
            "GD: -50.000 VND; Transaction : -60.000 VND",
            "GD: -50.000 VND; -60.000 VND", "GD: -50.000 VND; không thành công",
            // `CK` asserted by the bank as the transaction type still reviews.
            // The same abbreviation inside an `ND:` content line is the payer's
            // own shorthand, not a status, and is covered as an automatic save
            // in `BankNotificationParserTests`.
            "GD: -50.000 VND; LOAI GD: CK",
        ])
    func notificationRequiresReview(text: String) throws {
        let fixture = try makeFixture()
        let capture = try fixture.service.prepareNotification(
            BankNotificationEvent(text: text, source: "Bank", receivedAt: now),
            accountID: fixture.accountID, automaticSave: true)
        #expect(!capture.isReady)
        #expect(
            try ModelContext(fixture.container).fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
    }

    @Test("Notifications default to review and duplicate delivery creates only one pending item")
    func notificationDefaultsToReview() throws {
        let fixture = try makeFixture()
        fixture.defaults.set(
            fixture.accountID.uuidString, forKey: BankNotificationPreferences.accountKey)
        let event = BankNotificationEvent(text: "GD: -50,000 VND", source: "Bank", receivedAt: now)
        let first = try fixture.service.recordNotification(event, accountID: nil)
        let replay = try fixture.service.recordNotification(event, accountID: nil)
        #expect(first.result.disposition == .pendingReview)
        #expect(!first.duplicate)
        #expect(replay.duplicate)
        #expect(first.result.id == replay.result.id)
        let context = ModelContext(fixture.container)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
    }

    @Test("Automatic notification save is idempotent but permits equal payments at different times")
    func notificationAutomaticSave() throws {
        let fixture = try makeFixture()
        fixture.defaults.set(true, forKey: BankNotificationPreferences.automaticSaveKey)
        let event = BankNotificationEvent(text: "GD: -50,000 VND", source: "Bank", receivedAt: now)
        let first = try fixture.service.recordNotification(event, accountID: fixture.accountID)
        let replay = try fixture.service.recordNotification(event, accountID: fixture.accountID)
        #expect(first.result.disposition == .transaction)
        #expect(replay.duplicate)
        let later = BankNotificationEvent(
            text: event.text, source: event.source,
            receivedAt: now.addingTimeInterval(1))
        #expect(
            try !fixture.service.recordNotification(later, accountID: fixture.accountID).duplicate)
        #expect(
            try ModelContext(fixture.container).fetch(FetchDescriptor<MoneyTransaction>()).count
                == 2)
    }

    @Test("Income uses its own category and captures budget allocations")
    func notificationIncome() throws {
        let fixture = try makeFixture()
        fixture.defaults.set(true, forKey: BankNotificationPreferences.automaticSaveKey)
        fixture.defaults.set(
            fixture.incomeCategoryID.uuidString,
            forKey: TransactionDefaults.incomeCategoryStorageKey)
        _ = try fixture.service.recordNotification(
            BankNotificationEvent(
                text: "Giao dịch: +5.000.000 VND", source: "Bank", receivedAt: now),
            accountID: fixture.accountID)
        let transaction = try #require(
            ModelContext(fixture.container).fetch(FetchDescriptor<MoneyTransaction>()).first)
        #expect(transaction.kind == .income)
        #expect(transaction.categoryID == fixture.incomeCategoryID)
        #expect(
            try IncomeAllocationLifecycle.snapshot(in: transaction)?.allocatedAmount == 5_000_000)
    }

    @Test("Notification rejects an invalid explicit account without falling back to defaults")
    func notificationInvalidAccount() throws {
        let fixture = try makeFixture()
        fixture.defaults.set(
            fixture.accountID.uuidString, forKey: BankNotificationPreferences.accountKey)
        #expect(throws: TransactionCaptureServiceError.staleCapture) {
            try fixture.service.recordNotification(
                BankNotificationEvent(text: "GD: -50.000 VND", source: "Bank", receivedAt: now),
                accountID: UUID())
        }
        #expect(throws: TransactionCaptureServiceError.emptyCapture) {
            try fixture.service.recordNotification(
                BankNotificationEvent(text: "  ", source: "Bank", receivedAt: now),
                accountID: fixture.accountID)
        }
        let context = ModelContext(fixture.container)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
    }

    @Test("A reviewed notification retains its event identity for future retries")
    func notificationReviewIdentity() throws {
        let fixture = try makeFixture()
        let event = BankNotificationEvent(text: "GD: -50.000 VND", source: "Bank", receivedAt: now)
        let first = try fixture.service.recordNotification(event, accountID: fixture.accountID)
        let context = ModelContext(fixture.container)
        let pending = try #require(
            context.fetch(FetchDescriptor<PendingTransactionCapture>()).first)
        context.insert(try pending.draft.makeTransaction(id: pending.id, createdAt: now))
        context.delete(pending)
        try context.save()
        let replay = try fixture.service.recordNotification(event, accountID: fixture.accountID)
        #expect(replay.duplicate)
        #expect(replay.result.id == first.result.id)
        #expect(replay.result.disposition == .transaction)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).count == 1)
    }

    @Test(
        "The notification action uses an explicit account and reports receipt without saving in review mode"
    )
    func notificationActionAccountAndStatus() async throws {
        let fixture = try makeFixture()
        let context = ModelContext(fixture.container)
        let secondID = UUID()
        context.insert(
            CashAccount(
                id: secondID, name: "Other Bank", kind: .normal,
                openingBalance: 0, currencyCode: VNDCurrency.code, createdAt: now))
        try context.save()
        fixture.defaults.set(
            fixture.accountID.uuidString, forKey: BankNotificationPreferences.accountKey)
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container, defaults: fixture.defaults)
        let accounts = try await dependency.notificationAccounts()
        #expect(Set(accounts.map(\.id)) == [fixture.accountID, secondID])
        let event = BankNotificationEvent(
            text: "GD: -50.000 VND", source: "Other Bank", receivedAt: now)
        #expect(try await dependency.recordNotification(event, accountID: secondID) == "review")
        let pending = try #require(
            context.fetch(FetchDescriptor<PendingTransactionCapture>()).first)
        #expect(pending.accountID == secondID)
        #expect(
            fixture.defaults.string(forKey: BankNotificationPreferences.lastResultKey) == "review")
        #expect(fixture.defaults.double(forKey: BankNotificationPreferences.lastReceivedKey) > 0)
        #expect(try await dependency.recordNotification(event, accountID: secondID) == "duplicate")
    }

    @Test("Missing income defaults and malformed or oversized inputs never create transactions")
    func notificationMissingDefaultsAndInvalidInput() throws {
        let fixture = try makeFixture()
        let income = try fixture.service.prepareNotification(
            BankNotificationEvent(text: "GD: +50.000 VND", source: "Bank", receivedAt: now),
            accountID: fixture.accountID, automaticSave: true)
        #expect(income.issues.contains(.missingCategory))
        #expect(!income.isReady)
        for event in [
            BankNotificationEvent(text: "GD: -50.000 VND", source: "", receivedAt: now),
            BankNotificationEvent(
                text: String(repeating: "x", count: 16_385), source: "Bank", receivedAt: now),
        ] {
            #expect(throws: TransactionCaptureServiceError.emptyCapture) {
                try fixture.service.recordNotification(event, accountID: fixture.accountID)
            }
        }
        #expect(
            try ModelContext(fixture.container).fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
    }

    @Test("Apple Pay defaults to review independently of bank notification auto-save")
    func applePayReviewAndReplay() throws {
        let fixture = try makeFixture()
        fixture.defaults.set(true, forKey: BankNotificationPreferences.automaticSaveKey)
        let event = ApplePayEvent(
            amount: 50_000, currency: "VND", merchant: "Cafe 123", occurredAt: now)
        let first = try fixture.service.recordApplePay(event, accountID: fixture.accountID)
        let replay = try fixture.service.recordApplePay(event, accountID: fixture.accountID)
        #expect(first.result.disposition == .pendingReview)
        #expect(!first.duplicate)
        #expect(replay.duplicate)
        let context = ModelContext(fixture.container)
        let pending = try #require(
            context.fetch(FetchDescriptor<PendingTransactionCapture>()).first)
        #expect(pending.amount == 50_000)
        #expect(pending.note == "Cafe 123")
        #expect(pending.accountID == fixture.accountID)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        context.insert(try pending.draft.makeTransaction(id: pending.id, createdAt: now))
        context.delete(pending)
        try context.save()
        let approvedReplay = try fixture.service.recordApplePay(event, accountID: fixture.accountID)
        #expect(approvedReplay.duplicate)
        #expect(approvedReplay.result.id == first.result.id)
        #expect(approvedReplay.result.disposition == .transaction)
    }

    @Test("Apple Pay opt-in saves once and preserves equal payments at different times")
    func applePayAutomaticSave() throws {
        let fixture = try makeFixture()
        fixture.defaults.set(true, forKey: ApplePayPreferences.automaticSaveKey)
        fixture.defaults.set(fixture.accountID.uuidString, forKey: ApplePayPreferences.accountKey)
        let event = ApplePayEvent(
            amount: 50_000, currency: " vnd ", merchant: " Cafe ", occurredAt: now)
        let first = try fixture.service.recordApplePay(event, accountID: nil)
        let canonical = ApplePayEvent(
            amount: 50_000, currency: "VND", merchant: "Cafe", occurredAt: now)
        #expect(first.result.disposition == .transaction)
        #expect(try fixture.service.recordApplePay(canonical, accountID: nil).duplicate)
        let later = ApplePayEvent(
            amount: 50_000, currency: "VND", merchant: "Cafe", occurredAt: now.addingTimeInterval(1)
        )
        #expect(try !fixture.service.recordApplePay(later, accountID: nil).duplicate)
        let transactions = try ModelContext(fixture.container).fetch(
            FetchDescriptor<MoneyTransaction>())
        #expect(transactions.count == 2)
        #expect(
            transactions.allSatisfy {
                $0.kind == .expense && $0.amount == 50_000 && $0.note == "Cafe"
            })
    }

    @Test(
        "Apple Pay never assumes foreign or missing currency is VND",
        arguments: ["USD", "", "EUR", "đ"])
    func applePayUnsupportedCurrency(_ currency: String) throws {
        let fixture = try makeFixture()
        fixture.defaults.set(true, forKey: ApplePayPreferences.automaticSaveKey)
        let event = ApplePayEvent(amount: 12, currency: currency, merchant: "Cafe", occurredAt: now)
        let result = try fixture.service.recordApplePay(event, accountID: fixture.accountID)
        #expect(result.result.disposition == .pendingReview)
        let pending = try #require(
            ModelContext(fixture.container).fetch(FetchDescriptor<PendingTransactionCapture>())
                .first)
        #expect(pending.amount == nil)
        #expect(pending.draft.amountText.isEmpty)
        #expect(pending.rawText.contains("12"))
        #expect(pending.issues.contains(.unsupportedCurrency))
    }

    @Test(
        "Apple Pay rejects unsafe amounts without extracting merchant digits",
        arguments: [
            nil, Decimal.zero, Decimal(-1), Decimal.nan, Decimal(string: "1.5"),
            Decimal(string: "1000000000000000"),
        ])
    func applePayUnsafeAmounts(_ amount: Decimal?) throws {
        let fixture = try makeFixture()
        fixture.defaults.set(true, forKey: ApplePayPreferences.automaticSaveKey)
        let event = ApplePayEvent(
            amount: amount, currency: "VND", merchant: "Store 12345", occurredAt: now)
        let capture = try fixture.service.prepareApplePay(event, accountID: fixture.accountID)
        #expect(capture.amount == nil)
        #expect(!capture.isReady)
    }

    @Test("Apple Pay requires a merchant, selected account and valid category for auto-save")
    func applePayMissingFields() throws {
        let fixture = try makeFixture()
        fixture.defaults.set(true, forKey: ApplePayPreferences.automaticSaveKey)
        let missingMerchant = ApplePayEvent(
            amount: 50_000, currency: "VND", merchant: "  ", occurredAt: now)
        #expect(
            try !fixture.service.prepareApplePay(missingMerchant, accountID: fixture.accountID)
                .isReady)
        let event = ApplePayEvent(
            amount: 50_000, currency: "VND", merchant: "Cafe", occurredAt: now)
        let missingAccount = try fixture.service.prepareApplePay(event, accountID: nil)
        #expect(missingAccount.accountID == nil)
        #expect(missingAccount.issues.contains(.missingAccount))
        fixture.defaults.set(UUID().uuidString, forKey: TransactionDefaults.categoryStorageKey)
        let context = ModelContext(fixture.container)
        for category in try context.fetch(FetchDescriptor<TransactionCategory>()) {
            context.delete(category)
        }
        try context.save()
        #expect(
            try fixture.service.prepareApplePay(event, accountID: fixture.accountID).issues
                .contains(.missingCategory))
    }

    @Test("Apple Pay invalid explicit accounts and oversized or invalid dates fail without writes")
    func applePayInvalidInput() throws {
        let fixture = try makeFixture()
        fixture.defaults.set(fixture.accountID.uuidString, forKey: ApplePayPreferences.accountKey)
        let event = ApplePayEvent(
            amount: 50_000, currency: "VND", merchant: "Cafe", occurredAt: now)
        #expect(throws: TransactionCaptureServiceError.staleCapture) {
            try fixture.service.recordApplePay(event, accountID: UUID())
        }
        for invalid in [
            ApplePayEvent(
                amount: 50_000, currency: "VND", merchant: String(repeating: "x", count: 1025),
                occurredAt: now),
            ApplePayEvent(
                amount: 50_000, currency: "VND", merchant: "Cafe",
                occurredAt: Date(timeIntervalSince1970: .infinity)),
        ] {
            #expect(throws: TransactionCaptureServiceError.emptyCapture) {
                try fixture.service.recordApplePay(invalid, accountID: fixture.accountID)
            }
        }
        let context = ModelContext(fixture.container)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
    }

    @Test("Apple Pay action reports review, duplicate, saved and failure independently")
    func applePayActionStatus() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container, defaults: fixture.defaults)
        let event = ApplePayEvent(
            amount: 50_000, currency: "VND", merchant: "Cafe", occurredAt: now)
        #expect(
            try await dependency.recordApplePay(event, accountID: fixture.accountID) == "review")
        #expect(fixture.defaults.string(forKey: ApplePayPreferences.lastResultKey) == "review")
        #expect(
            try await dependency.recordApplePay(event, accountID: fixture.accountID) == "duplicate")
        fixture.defaults.set(true, forKey: ApplePayPreferences.automaticSaveKey)
        let later = ApplePayEvent(
            amount: 50_000, currency: "VND", merchant: "Cafe", occurredAt: now.addingTimeInterval(1)
        )
        #expect(try await dependency.recordApplePay(later, accountID: fixture.accountID) == "saved")
        do {
            _ = try await dependency.recordApplePay(event, accountID: UUID())
            Issue.record("Expected a stale account error")
        } catch {
            #expect(fixture.defaults.string(forKey: ApplePayPreferences.lastResultKey) == "failed")
        }
        #expect(fixture.defaults.double(forKey: ApplePayPreferences.lastReceivedKey) > 0)
        #expect(fixture.defaults.object(forKey: BankNotificationPreferences.lastResultKey) == nil)
    }

    @Test("Apple Pay rolls back when sync prevents writing", arguments: [false, true])
    func applePaySaveFailure(_ automaticSave: Bool) throws {
        let fixture = try makeFixture()
        fixture.defaults.set(automaticSave, forKey: ApplePayPreferences.automaticSaveKey)
        SyncWriteGate.lock(fixture.container)
        defer { SyncWriteGate.unlock(fixture.container) }
        let event = ApplePayEvent(
            amount: 50_000, currency: "VND", merchant: "Cafe", occurredAt: now)
        #expect(throws: TransactionCaptureServiceError.storeFailure) {
            try fixture.service.recordApplePay(event, accountID: fixture.accountID)
        }
        let context = ModelContext(fixture.container)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        SyncWriteGate.unlock(fixture.container)
        #expect(try !fixture.service.recordApplePay(event, accountID: fixture.accountID).duplicate)
    }

    @Test("Apple Pay identity separates cards, accounts, currencies and capture sources")
    func applePayIdentityScope() throws {
        let fixture = try makeFixture()
        let event = ApplePayEvent(
            amount: 50_000, currency: "VND", merchant: "Cafe", occurredAt: now, card: "Visa")
        let otherCard = ApplePayEvent(
            amount: 50_000, currency: "VND", merchant: "Cafe", occurredAt: now, card: "Mastercard")
        #expect(
            event.id(accountID: fixture.accountID) != otherCard.id(accountID: fixture.accountID))
        #expect(event.id(accountID: fixture.accountID) != event.id(accountID: UUID()))
        let foreign = ApplePayEvent(
            amount: 50_000, currency: "USD", merchant: "Cafe", occurredAt: now, card: "Visa")
        #expect(event.id(accountID: fixture.accountID) != foreign.id(accountID: fixture.accountID))
        let bank = BankNotificationEvent(text: "GD: -50.000 VND", source: "Bank", receivedAt: now)
        #expect(event.id(accountID: fixture.accountID) != bank.id(accountID: fixture.accountID))
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let accountID = UUID()
        let categoryID = UUID()
        let transportCategoryID = UUID()
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
                id: transportCategoryID,
                name: "Đi lại",
                kind: .expense,
                symbolName: "car.fill",
                colorName: "blue",
                createdAt: now.addingTimeInterval(1)
            )
        )
        context.insert(
            TransactionCategory(
                id: incomeCategoryID,
                name: "Lương",
                kind: .income,
                symbolName: "banknote.fill",
                colorName: "green",
                createdAt: now.addingTimeInterval(2)
            )
        )
        context.insert(
            BudgetJar(
                id: UUID(),
                name: "Savings",
                allocationPercent: 100,
                role: .savings,
                symbolName: "building.columns.fill",
                colorName: "yellow",
                createdAt: now.addingTimeInterval(3)
            )
        )
        try context.save()

        let suiteName = "TransactionCaptureServiceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(accountID.uuidString, forKey: TransactionDefaults.accountStorageKey)
        defaults.set(categoryID.uuidString, forKey: TransactionDefaults.categoryStorageKey)

        return Fixture(
            container: container,
            service: TransactionCaptureService(container: container, defaults: defaults),
            defaults: defaults,
            accountID: accountID,
            categoryID: categoryID,
            transportCategoryID: transportCategoryID,
            incomeCategoryID: incomeCategoryID
        )
    }

    private struct Fixture {
        let container: ModelContainer
        let service: TransactionCaptureService
        let defaults: UserDefaults
        let accountID: UUID
        let categoryID: UUID
        let transportCategoryID: UUID
        let incomeCategoryID: UUID
    }
}
