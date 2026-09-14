import CryptoKit
import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Salary profile")
@MainActor
struct SalaryProfileTests {
    @Test func savesDealBasisAndRestoresAllInputs() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var draft = SalaryProfileDraft()
        draft.name = "  An  "
        draft.amountText = "30000000"
        draft.basis = .net
        draft.dependants = 2
        draft.period = .firstHalf
        draft.region = .iv
        draft.customInsurance = true
        draft.insuranceText = "5000000"
        let profile = try SalaryProfileStore.save(draft, in: container.mainContext)
        let saved = try #require(
            ModelContext(container).fetch(FetchDescriptor<SalaryProfile>()).first)
        #expect(profile.id == SalaryProfile.personalID)
        #expect(saved.name == "An")
        #expect(saved.basisRaw == "net")
        let reopened = SalaryProfileDraft(profile: saved)
        #expect(reopened.basis == .net)
        #expect(reopened.dependants == 2)
        #expect(reopened.period == .firstHalf)
        #expect(reopened.region == .iv)
        #expect(reopened.customInsurance)
        #expect(reopened.result?.net == 30_000_000)
        #expect(reopened.result?.gross == draft.result?.gross)

        draft.basis = .gross
        _ = try SalaryProfileStore.save(draft, in: container.mainContext)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<SalaryProfile>()) == 1)
        #expect(profile.basisRaw == "gross")
    }

    @Test func invalidDraftDoesNotChangeSavedProfile() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var draft = SalaryProfileDraft()
        draft.name = "An"
        draft.amountText = "30000000"
        let saved = try SalaryProfileStore.save(draft, in: container.mainContext)
        draft.amountText = "-5"
        #expect(throws: SalaryProfileError.invalidInput) {
            try SalaryProfileStore.save(draft, in: container.mainContext)
        }
        #expect(saved.amount == 30_000_000)
        draft.amountText = "30000000"
        draft.customInsurance = true
        #expect(draft.result == nil)
        draft.insuranceText = "-1"
        #expect(draft.result == nil)
        draft.insuranceText = "0"
        #expect(draft.result != nil)
        draft.dependants = 21
        #expect(draft.result == nil)
    }

    @Test func explicitLinkNeverFallsBackToAnotherSalary() throws {
        let rule = RecurringRule(
            id: UUID(), kind: .income, amount: 20_000_000, note: "Salary",
            accountID: UUID(), categoryID: nil, currencyCode: "VND",
            frequency: .monthly, interval: 1, anchorDate: .now, endDate: nil,
            isPaused: false, lastGeneratedAt: nil, createdAt: .now)
        #expect(SalaryProfileStore.linkedRule(id: nil, in: [rule]) == nil)
        #expect(SalaryProfileStore.linkedRule(id: UUID(), in: [rule]) == nil)
        #expect(SalaryProfileStore.linkedRule(id: rule.id, in: [rule])?.id == rule.id)
        rule.kind = .expense
        #expect(SalaryProfileStore.linkedRule(id: rule.id, in: [rule]) == nil)
    }

    @Test func backupAndSyncRoundTripProfile() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var draft = SalaryProfileDraft()
        draft.name = "An"
        draft.amountText = "30000000"
        draft.basis = .net
        // A deleted rule is an optional link, not a reason to lose the profile.
        draft.recurringRuleID = UUID()
        _ = try SalaryProfileStore.save(draft, in: container.mainContext)
        let service = MonMonBackupService(container: container)
        let data = try service.exportData()
        let validated = try service.preview(data)
        #expect(validated.payload.recordCount == 1)
        let sync = try SyncSnapshot(payload: validated.payload)
        #expect(sync.records.contains { $0.type == "salaryProfiles" })
        let roundTripped = try sync.validated()
        let destination = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        try MonMonBackupService(container: destination).apply(
            roundTripped, in: destination.mainContext, includeDeviceData: false)
        try destination.mainContext.save()
        let restored = try #require(try SalaryProfileStore.personal(in: destination.mainContext))
        #expect(restored.basisRaw == "net")
        #expect(restored.amount == 30_000_000)
        #expect(restored.recurringRuleID == draft.recurringRuleID)
    }

    @Test func failedLinkSaveRollsBackWithoutChangingScheduleOrHistory() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var draft = SalaryProfileDraft()
        draft.name = "An"
        draft.amountText = "30000000"
        let profile = try SalaryProfileStore.save(draft, in: container.mainContext)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let rule = RecurringRule(
            id: UUID(), kind: .income, amount: 20_000_000, note: "Salary",
            accountID: UUID(), categoryID: nil, currencyCode: "VND",
            frequency: .monthly, interval: 1, anchorDate: day, endDate: nil,
            isPaused: true, lastGeneratedAt: day, createdAt: day)
        container.mainContext.insert(rule)
        try container.mainContext.save()
        enum Failure: Error { case save }
        #expect(throws: Failure.save) {
            try SalaryProfileStore.saveLinkedRule(rule, in: container.mainContext) { _ in
                throw Failure.save
            }
        }
        #expect(
            try SalaryProfileStore.personal(in: ModelContext(container))?.recurringRuleID == nil)
        #expect(profile.recurringRuleID == nil)
        try SalaryProfileStore.saveLinkedRule(rule, in: container.mainContext)
        #expect(profile.recurringRuleID == rule.id)
        #expect(rule.amount == 20_000_000)
        #expect(rule.anchorDate == day)
        #expect(rule.lastGeneratedAt == day)
        #expect(rule.isPaused)
    }

    @Test func legacyBackupKeepsOriginalChecksumAndHasNoProfile() throws {
        let document = try MonMonBackupDocument.make(
            payload: .empty, exportedAt: .now, appVersion: "old", flavour: .current)
        var root = try #require(
            JSONSerialization.jsonObject(with: MonMonBackupCodec.encode(document)) as? [String: Any]
        )
        var payload = try #require(root["payload"] as? [String: Any])
        payload.removeValue(forKey: "salaryProfiles")
        let canonical = try JSONSerialization.data(
            withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes])
        root["payload"] = payload
        root["payloadSHA256"] = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }
            .joined()
        let oldData = try JSONSerialization.data(withJSONObject: root)
        let old = try MonMonBackupValidator.decodeAndValidate(oldData)
        #expect(old.payload.salaryProfiles.isEmpty)
        #expect(try SyncSnapshot(payload: old.payload).records.isEmpty)
    }

    @Test func syncRemapsExplicitLinkAndAllowsDeletedRule() throws {
        let oldID = MonMonBackupScalar.uuid(UUID())
        let newID = MonMonBackupScalar.uuid(UUID())
        let profile = SyncRecord(
            type: "salaryProfiles",
            fields: [
                "id": .string(MonMonBackupScalar.uuid(SalaryProfile.personalID)),
                "recurringRuleID": .string(oldID),
            ])
        let remapped = SyncMergePlanner.remap(
            profile, aliases: ["recurringRules/" + oldID: "recurringRules/" + newID])
        #expect(remapped.fields["recurringRuleID"]?.text == newID)
        let rule = SyncRecord(type: "recurringRules", fields: ["id": .string(oldID)])
        try SyncSnapshot(records: [profile]).validateDeletions(from: [profile, rule])
    }

    @Test func resetBacksUpProfileBeforeRemovingIt() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var draft = SalaryProfileDraft()
        draft.name = "An"
        draft.amountText = "30000000"
        draft.basis = .net
        _ = try SalaryProfileStore.save(draft, in: container.mainContext)
        let url = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let service = MonMonBackupService(container: container, defaults: defaults)
        try service.reset(backupURL: url)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<SalaryProfile>()) == 0)
        let backup = try service.preview(Data(contentsOf: url))
        #expect(backup.payload.salaryProfiles.first?.basis == "net")
        #expect(backup.payload.salaryProfiles.first?.amount == "30000000")
    }

    @Test func existingStoreMigratesAndProfileSurvivesReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "data.store")
        let oldSchema = Schema(MonMonSchema.models.filter { $0 != SalaryProfile.self })
        let accountID = UUID()
        do {
            let old = try ModelContainer(
                for: oldSchema,
                configurations: ModelConfiguration(
                    schema: oldSchema, url: url, cloudKitDatabase: .none))
            old.mainContext.insert(
                CashAccount(
                    id: accountID, name: "Wallet", kind: .normal, openingBalance: 100,
                    currencyCode: "VND", createdAt: .now))
            try old.mainContext.save()
        }
        let schema = Schema(MonMonSchema.models)
        do {
            let migrated = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(
                    schema: schema, url: url, cloudKitDatabase: .none))
            #expect(
                try migrated.mainContext.fetch(FetchDescriptor<CashAccount>()).first?.id
                    == accountID)
            var draft = SalaryProfileDraft()
            draft.name = "An"
            draft.amountText = "30000000"
            draft.basis = .net
            _ = try SalaryProfileStore.save(draft, in: migrated.mainContext)
        }
        let reopened = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        #expect(try SalaryProfileStore.personal(in: reopened.mainContext)?.basisRaw == "net")
    }
}
