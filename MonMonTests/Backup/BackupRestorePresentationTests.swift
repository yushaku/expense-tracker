import Foundation
import Testing

@testable import MonMon

@Suite("Backup and restore presentation")
struct BackupRestorePresentationTests {
    @Test("Suggested filenames are local, stable, and JSON")
    func filename() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let timeZone = TimeZone(secondsFromGMT: 7 * 60 * 60) ?? .gmt

        #expect(
            MonMonBackupFilename.make(date: date, timeZone: timeZone)
                == "MonMon-backup-2023-11-15-051320.json"
        )
    }

    @Test("User-facing failures are specific without echoing underlying data")
    func safeErrors() {
        #expect(
            MonMonBackupUserMessage.error(MonMonBackupValidationError.checksumMismatch)
                == "The backup is damaged or was edited."
        )
        #expect(
            MonMonBackupUserMessage.error(MonMonBackupServiceError.storeFailure)
                == "MonMon couldn’t replace the local data. Your previous data is still available."
        )

        struct SensitiveError: LocalizedError {
            var errorDescription: String? { "private account note and /owner/path" }
        }
        let message = MonMonBackupUserMessage.error(SensitiveError())
        #expect(!message.contains("private account note"))
        #expect(!message.contains("/owner/path"))
    }
}
