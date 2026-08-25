struct ImportSourceID: RawRepresentable, Equatable, Hashable, Sendable {
    let rawValue: String

    init?(rawValue: String) {
        guard rawValue.utf8.count == 64,
            rawValue.utf8.allSatisfy({ byte in
                (48...57).contains(byte) || (97...102).contains(byte)
            })
        else {
            return nil
        }

        self.rawValue = rawValue
    }
}
