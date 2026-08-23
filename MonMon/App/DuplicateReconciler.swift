import Foundation

/// Which row survives when the same thing exists twice, and which rows have to
/// fold into it.
///
/// Kept free of SwiftData so the rule can be tested on plain values. The store
/// side lives in `StoreReconciler`.
enum DuplicateReconciler {
    struct Merge<Element> {
        let survivor: Element
        let duplicates: [Element]
    }

    /// Groups by `key`, dropping every group that holds only one row.
    ///
    /// The survivor is the **oldest** by `createdAt`, with ties broken by the
    /// smaller id. Both halves matter. Oldest-wins matches the rule
    /// `FundInstrumentSeed` already used — the first thing the owner entered
    /// beats a later duplicate of it — and the tie-break is what makes the
    /// answer the same on every device. Two devices that disagreed about the
    /// survivor would each delete what the other kept, and the pair of them
    /// would erase the row entirely.
    static func merges<Element>(
        in elements: [Element],
        key: (Element) -> String,
        createdAt: (Element) -> Date,
        id: (Element) -> UUID
    ) -> [Merge<Element>] {
        var groups: [String: [Element]] = [:]
        var order: [String] = []

        for element in elements {
            let groupKey = key(element)
            guard !groupKey.isEmpty else {
                continue
            }
            if groups[groupKey] == nil {
                order.append(groupKey)
            }
            groups[groupKey, default: []].append(element)
        }

        return order.compactMap { groupKey in
            guard let members = groups[groupKey], members.count > 1 else {
                return nil
            }

            let sorted = members.sorted { left, right in
                let leftDate = createdAt(left)
                let rightDate = createdAt(right)
                if leftDate != rightDate {
                    return leftDate < rightDate
                }
                return id(left).uuidString < id(right).uuidString
            }

            guard let survivor = sorted.first else {
                return nil
            }

            return Merge(survivor: survivor, duplicates: Array(sorted.dropFirst()))
        }
    }
}
