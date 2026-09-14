import Foundation
import SwiftData

enum SalaryBasis: String, CaseIterable, Identifiable {
    case gross, net
    var id: Self { self }
}

/// One personal profile shared by the owner's devices. The stable identity
/// makes independently edited profiles a sync conflict, not two separate users.
@Model
final class SalaryProfile {
    static let personalID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 1))

    var id: UUID = UUID()
    var name: String = ""
    var amount: Decimal = Decimal.zero
    var basisRaw: String = "gross"
    var dependants: Int = 0
    var periodRaw: String = "Jul–Dec 2026"
    var regionRaw: Int = 1
    var insuranceSalary: Decimal?
    /// Weak link: a removed or repurposed rule leaves the profile intact.
    var recurringRuleID: UUID?
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var updatedAt: Date = Date(timeIntervalSince1970: 0)

    init(createdAt: Date) {
        id = Self.personalID
        self.createdAt = createdAt
        updatedAt = createdAt
    }
}

enum SalaryProfileError: Error, Equatable {
    case invalidInput, missingProfile, incompatibleRule
}

struct SalaryProfileDraft: Equatable {
    var name = ""
    var amountText = ""
    var basis = SalaryBasis.gross
    var dependants = 0
    var period = SalaryCalculator.Period.secondHalf
    var region = SalaryCalculator.Region.i
    var customInsurance = false
    var insuranceText = ""
    var recurringRuleID: UUID?

    init() {}

    init(profile: SalaryProfile) {
        name = profile.name
        amountText = VNDCurrency.formatPlain(profile.amount)
        basis = SalaryBasis(rawValue: profile.basisRaw) ?? .gross
        dependants = profile.dependants
        period = SalaryCalculator.Period(rawValue: profile.periodRaw) ?? .secondHalf
        region = SalaryCalculator.Region(rawValue: profile.regionRaw) ?? .i
        customInsurance = profile.insuranceSalary != nil
        insuranceText = profile.insuranceSalary.map(VNDCurrency.formatPlain) ?? ""
        recurringRuleID = profile.recurringRuleID
    }

    var result: SalaryCalculator.Result? {
        guard let amount = VNDCurrency.parse(amountText) else { return nil }
        let insurance = customInsurance ? VNDCurrency.parse(insuranceText) : nil
        guard !customInsurance || insurance != nil else { return nil }
        return SalaryCalculator.calculate(
            amount: amount, fromNet: basis == .net, dependants: dependants,
            period: period, region: region, insuranceSalary: insurance)
    }

    var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && trimmedName.count <= 100 && result != nil
    }

    func apply(to profile: SalaryProfile, now: Date = .now) throws {
        guard isValid, let amount = VNDCurrency.parse(amountText) else {
            throw SalaryProfileError.invalidInput
        }
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.amount = amount
        profile.basisRaw = basis.rawValue
        profile.dependants = dependants
        profile.periodRaw = period.rawValue
        profile.regionRaw = region.rawValue
        profile.insuranceSalary = customInsurance ? VNDCurrency.parse(insuranceText) : nil
        profile.recurringRuleID = recurringRuleID
        profile.updatedAt = now
    }
}

@MainActor
enum SalaryProfileStore {
    static func personal(in context: ModelContext) throws -> SalaryProfile? {
        let id = SalaryProfile.personalID
        return try context.fetch(
            FetchDescriptor<SalaryProfile>(predicate: #Predicate { $0.id == id })
        )
        .first
    }

    @discardableResult
    static func save(_ draft: SalaryProfileDraft, in context: ModelContext) throws -> SalaryProfile
    {
        guard draft.isValid else { throw SalaryProfileError.invalidInput }
        let profile = try personal(in: context) ?? SalaryProfile(createdAt: .now)
        let previous = profile.modelContext == nil ? nil : SalaryProfileDraft(profile: profile)
        let previousUpdatedAt = profile.updatedAt
        do {
            try draft.apply(to: profile)
            if profile.modelContext == nil { context.insert(profile) }
            context.processPendingChanges()
            try SyncWriteGate.save(context)
            return profile
        } catch {
            context.rollback()
            if let previous {
                try? previous.apply(to: profile, now: previousUpdatedAt)
            }
            throw error
        }
    }

    static func isCompatible(_ rule: RecurringRule) -> Bool {
        rule.kind == .income && rule.currencyCode == VNDCurrency.code
            && rule.frequency == .monthly && rule.interval == 1
    }

    static func linkedRule(id: UUID?, in rules: [RecurringRule]) -> RecurringRule? {
        guard let id else { return nil }
        return rules.first { $0.id == id && isCompatible($0) }
    }

    /// Commit the rule and its link together. Restore the retained model too:
    /// SwiftData rollback can leave a formerly nil UUID cached on that instance.
    static func saveLinkedRule(
        _ rule: RecurringRule, in context: ModelContext,
        save: (ModelContext) throws -> Void = { try SyncWriteGate.save($0) }
    ) throws {
        guard isCompatible(rule) else { throw SalaryProfileError.incompatibleRule }
        guard let profile = try personal(in: context) else {
            throw SalaryProfileError.missingProfile
        }
        let previousID = profile.recurringRuleID
        let previousUpdatedAt = profile.updatedAt
        do {
            profile.recurringRuleID = rule.id
            profile.updatedAt = .now
            try save(context)
        } catch {
            context.rollback()
            profile.recurringRuleID = previousID
            profile.updatedAt = previousUpdatedAt
            throw error
        }
    }
}

extension MonMonBackupService {
    static func salaryProfileRecord(_ model: SalaryProfile)
        -> MonMonBackupPayload.SalaryProfileRecord
    {
        MonMonBackupPayload.SalaryProfileRecord(
            id: MonMonBackupScalar.uuid(model.id), name: model.name,
            amount: MonMonBackupScalar.decimal(model.amount), basis: model.basisRaw,
            dependants: model.dependants, period: model.periodRaw, region: model.regionRaw,
            insuranceSalary: model.insuranceSalary.map(MonMonBackupScalar.decimal),
            recurringRuleID: model.recurringRuleID.map(MonMonBackupScalar.uuid),
            createdAt: MonMonBackupScalar.date(model.createdAt),
            updatedAt: MonMonBackupScalar.date(model.updatedAt))
    }

    func makeSalaryProfile(_ record: MonMonBackupPayload.SalaryProfileRecord) throws
        -> SalaryProfile
    {
        let model = SalaryProfile(createdAt: try MonMonBackupScalar.parseDate(record.createdAt))
        try updateSalaryProfile(model, record)
        return model
    }

    func updateSalaryProfile(
        _ model: SalaryProfile, _ record: MonMonBackupPayload.SalaryProfileRecord
    ) throws {
        model.id = try MonMonBackupScalar.parseUUID(record.id)
        model.name = record.name
        model.amount = try MonMonBackupScalar.parseDecimal(record.amount)
        model.basisRaw = record.basis
        model.dependants = record.dependants
        model.periodRaw = record.period
        model.regionRaw = record.region
        model.insuranceSalary = try record.insuranceSalary.map(MonMonBackupScalar.parseDecimal)
        model.recurringRuleID = try record.recurringRuleID.map(MonMonBackupScalar.parseUUID)
        model.createdAt = try MonMonBackupScalar.parseDate(record.createdAt)
        model.updatedAt = try MonMonBackupScalar.parseDate(record.updatedAt)
    }
}
