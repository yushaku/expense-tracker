import CryptoKit
import Foundation

struct StagedBankStatement: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let originalFilename: String
    let byteCount: Int
    let createdAt: Date
}

enum StatementIntakeError: Error, Sendable, Equatable {
    case appGroupUnavailable
    case unsupportedPDF
    case oversizedFile(maximumBytes: Int)
    case unreadableInput
    case malformedStagedItem
    case fileSystem
}

struct StatementIntakeStore: Sendable {
    static let maximumByteCount = 25 * 1_024 * 1_024

    private static let inboxDirectoryName = "BankStatementInbox"
    private static let readyDirectoryName = "ready"
    private static let statementFilename = "statement.pdf"
    private static let manifestFilename = "manifest.json"
    private static let pdfSignature = Data("%PDF-".utf8)

    private let rootURL: URL
    private let now: @Sendable () -> Date

    init(
        rootURL: URL,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.rootURL = rootURL
        self.now = now
    }

    func stagePDF(at sourceURL: URL, originalFilename: String) throws -> StagedBankStatement {
        do {
            let values = try sourceURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true, let byteCount = values.fileSize else {
                throw StatementIntakeError.unreadableInput
            }
            guard byteCount <= Self.maximumByteCount else {
                throw StatementIntakeError.oversizedFile(
                    maximumBytes: Self.maximumByteCount
                )
            }
            let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
            guard !data.isEmpty, data.starts(with: Self.pdfSignature) else {
                throw StatementIntakeError.unsupportedPDF
            }
            guard data.count <= Self.maximumByteCount else {
                throw StatementIntakeError.oversizedFile(
                    maximumBytes: Self.maximumByteCount
                )
            }

            let id = contentID(for: data)
            let readyURL = try readyDirectoryURL()
            let destinationURL = readyURL.appendingPathComponent(id, isDirectory: true)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                return try existingItem(at: destinationURL, matching: data)
            }

            let staged = StagedBankStatement(
                id: id,
                originalFilename: sanitizedFilename(originalFilename),
                byteCount: data.count,
                createdAt: manifestDate(now())
            )
            let partialURL = inboxDirectoryURL.appendingPathComponent(
                ".partial-\(UUID().uuidString)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: partialURL,
                withIntermediateDirectories: false
            )
            defer { try? FileManager.default.removeItem(at: partialURL) }

            try data.write(
                to: partialURL.appendingPathComponent(Self.statementFilename),
                options: .atomic
            )
            let manifestData = try manifestEncoder.encode(staged)
            try manifestData.write(
                to: partialURL.appendingPathComponent(Self.manifestFilename),
                options: .atomic
            )

            do {
                try FileManager.default.moveItem(at: partialURL, to: destinationURL)
                return staged
            } catch {
                guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                    throw StatementIntakeError.fileSystem
                }
                return try existingItem(at: destinationURL, matching: data)
            }
        } catch let error as StatementIntakeError {
            throw error
        } catch is DecodingError {
            throw StatementIntakeError.malformedStagedItem
        } catch {
            throw StatementIntakeError.fileSystem
        }
    }

    func pendingStatements() throws -> [StagedBankStatement] {
        do {
            let readyURL = try readyDirectoryURL()
            let itemURLs = try FileManager.default.contentsOfDirectory(
                at: readyURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            return itemURLs.compactMap { try? validatedManifest(at: $0) }
                .sorted {
                    if $0.createdAt == $1.createdAt {
                        return $0.id < $1.id
                    }
                    return $0.createdAt < $1.createdAt
                }
        } catch let error as StatementIntakeError {
            throw error
        } catch {
            throw StatementIntakeError.fileSystem
        }
    }

    func data(for statement: StagedBankStatement) throws -> Data {
        do {
            guard isValidID(statement.id) else {
                throw StatementIntakeError.malformedStagedItem
            }
            let itemURL = try readyDirectoryURL().appendingPathComponent(
                statement.id,
                isDirectory: true
            )
            let storedManifest = try validatedManifest(at: itemURL)
            guard storedManifest == statement else {
                throw StatementIntakeError.malformedStagedItem
            }
            let data = try Data(
                contentsOf: itemURL.appendingPathComponent(Self.statementFilename),
                options: .mappedIfSafe
            )
            guard
                data.count == statement.byteCount,
                data.count <= Self.maximumByteCount,
                data.starts(with: Self.pdfSignature),
                contentID(for: data) == statement.id
            else {
                throw StatementIntakeError.malformedStagedItem
            }
            return data
        } catch let error as StatementIntakeError {
            throw error
        } catch {
            throw StatementIntakeError.malformedStagedItem
        }
    }

    func remove(_ statement: StagedBankStatement) throws {
        do {
            guard isValidID(statement.id) else {
                throw StatementIntakeError.malformedStagedItem
            }
            let itemURL = try readyDirectoryURL().appendingPathComponent(
                statement.id,
                isDirectory: true
            )
            guard FileManager.default.fileExists(atPath: itemURL.path) else {
                return
            }
            guard try validatedManifest(at: itemURL) == statement else {
                throw StatementIntakeError.malformedStagedItem
            }
            try FileManager.default.removeItem(at: itemURL)
        } catch let error as StatementIntakeError {
            throw error
        } catch {
            throw StatementIntakeError.fileSystem
        }
    }

    private var inboxDirectoryURL: URL {
        rootURL.appendingPathComponent(Self.inboxDirectoryName, isDirectory: true)
    }

    private var manifestEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private var manifestDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    private func readyDirectoryURL() throws -> URL {
        let readyURL = inboxDirectoryURL.appendingPathComponent(
            Self.readyDirectoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: readyURL,
            withIntermediateDirectories: true
        )
        var inboxURL = inboxDirectoryURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try inboxURL.setResourceValues(values)
        return readyURL
    }

    private func existingItem(at itemURL: URL, matching data: Data) throws -> StagedBankStatement {
        let statement = try validatedManifest(at: itemURL)
        guard
            statement.byteCount == data.count,
            statement.id == contentID(for: data),
            try self.data(for: statement) == data
        else {
            throw StatementIntakeError.malformedStagedItem
        }
        return statement
    }

    private func validatedManifest(at itemURL: URL) throws -> StagedBankStatement {
        let values = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else {
            throw StatementIntakeError.malformedStagedItem
        }
        let manifestData = try Data(
            contentsOf: itemURL.appendingPathComponent(Self.manifestFilename)
        )
        let statement = try manifestDecoder.decode(StagedBankStatement.self, from: manifestData)
        let statementURL = itemURL.appendingPathComponent(Self.statementFilename)
        let statementValues = try statementURL.resourceValues(
            forKeys: [.fileSizeKey, .isRegularFileKey]
        )
        guard
            isValidID(statement.id),
            itemURL.lastPathComponent == statement.id,
            statement.originalFilename == sanitizedFilename(statement.originalFilename),
            statement.byteCount > 0,
            statement.byteCount <= Self.maximumByteCount,
            statementValues.isRegularFile == true,
            statementValues.fileSize == statement.byteCount
        else {
            throw StatementIntakeError.malformedStagedItem
        }
        return statement
    }

    private func contentID(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func manifestDate(_ date: Date) -> Date {
        let milliseconds = (date.timeIntervalSince1970 * 1_000).rounded(.down)
        return Date(timeIntervalSince1970: milliseconds / 1_000)
    }

    private func isValidID(_ id: String) -> Bool {
        id.utf8.count == 64
            && id.utf8.allSatisfy {
                (48...57).contains($0) || (97...102).contains($0)
            }
    }

    private func sanitizedFilename(_ filename: String) -> String {
        let leaf =
            filename.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
            .last
            .map(String.init) ?? "statement.pdf"
        let filtered = leaf.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }
        let normalized = String(String.UnicodeScalarView(filtered))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safe =
            normalized.isEmpty || normalized == "." || normalized == ".."
            ? "statement.pdf"
            : normalized
        return String(safe.prefix(120))
    }
}
