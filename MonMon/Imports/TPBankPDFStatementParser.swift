import Foundation
import PDFKit

struct BankStatementMetadata: Sendable, Equatable {
    let bank: BankStatementBank
    let accountLastFour: String?
    let currencyCode: String
    let period: ClosedRange<Date>
}

struct TPBankPDFStatementParser: BankStatementParsing {
    private let maximumByteCount = 25 * 1_024 * 1_024
    private static let amountExpression = try? NSRegularExpression(
        pattern: #"(?<![0-9A-Za-z/:\-])\d(?:[\d.,]*\d)?(?![0-9A-Za-z/:\-])"#
    )

    func parse(_ data: Data) throws -> ParsedBankStatement {
        let document = try validatedDocument(from: data)
        let metadata = try metadata(in: document)
        var candidates: [BankTransactionCandidate] = []
        var issues: [BankStatementIssue] = []

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                continue
            }
            let result = try rows(on: page, pageIndex: pageIndex, metadata: metadata)
            candidates += result.candidates
            issues += result.issues
        }
        guard !candidates.isEmpty else {
            throw BankStatementParserError.noTransactionRows
        }
        let totals = BankStatementTotals(
            debit: candidates.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount },
            credit: candidates.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
        )
        let declaredTotals = declaredTotals(in: document)
        if let declaredTotals, declaredTotals != totals {
            issues.append(.totalsMismatch)
        }
        return ParsedBankStatement(
            bank: metadata.bank,
            accountLastFour: metadata.accountLastFour,
            currencyCode: metadata.currencyCode,
            period: metadata.period,
            candidates: candidates,
            declaredTotals: declaredTotals,
            parsedTotals: totals,
            issues: issues
        )
    }

    func metadata(from data: Data) throws -> BankStatementMetadata {
        let document = try validatedDocument(from: data)
        return try metadata(in: document)
    }

    private func metadata(in document: PDFDocument) throws -> BankStatementMetadata {
        let text = try text(from: document)
        let normalizedText = normalized(text)

        let isAccountStatement =
            normalizedText.contains("ACCOUNT STATEMENT")
            && normalizedText.contains("SAO KE TAI KHOAN")
        let isExtractionConfirmation =
            normalizedText.contains("STATEMENT EXTRACTION CONFIRMATION")
            && normalizedText.contains("XAC NHAN TRICH DAN SAO KE")
        guard
            normalizedText.contains("TPBANK") || normalizedText.contains("TIEN PHONG"),
            isAccountStatement || isExtractionConfirmation
        else {
            throw BankStatementParserError.unsupportedFormat
        }
        let columns = [
            "TRANSACTION DATE", "REFERENCE NUMBER", "EXPLANATION", "DEBIT", "CREDIT",
        ]
        guard columns.allSatisfy(normalizedText.contains) else {
            throw BankStatementParserError.unrecognizedLayout
        }

        let header = text.components(separatedBy: "Transaction Date").first ?? text
        guard
            let period = statementPeriod(in: header),
            normalized(header).range(of: #"\bVND\b"#, options: .regularExpression) != nil
        else {
            throw BankStatementParserError.invalidStatementMetadata
        }
        return BankStatementMetadata(
            bank: .tpBank,
            accountLastFour: accountLastFour(in: document, header: header),
            currencyCode: "VND",
            period: period
        )
    }

    private func rows(
        on page: PDFPage,
        pageIndex: Int,
        metadata: BankStatementMetadata
    ) throws -> (candidates: [BankTransactionCandidate], issues: [BankStatementIssue]) {
        let layout: ColumnLayout
        do {
            layout = try columnLayout(on: page)
        } catch BankStatementParserError.unrecognizedLayout {
            guard containsTransactionTimestamp(on: page) else {
                return ([], [])
            }
            throw BankStatementParserError.unrecognizedLayout
        }
        let anchors = dateAnchors(on: page, in: layout.dateRange)
        let pageAmounts = positionedAmounts(
            on: page,
            minimumX: layout.debitRange.lowerBound,
            maximumX: layout.creditRange.upperBound
        )
        var candidates: [BankTransactionCandidate] = []
        var issues: [BankStatementIssue] = []

        for (rowIndex, anchor) in anchors.enumerated() {
            let top =
                rowIndex == 0
                ? (layout.headerBottom + anchor.bounds.maxY) / 2
                : (anchors[rowIndex - 1].bounds.minY + anchor.bounds.maxY) / 2
            let bottom =
                rowIndex + 1 < anchors.count
                ? (anchor.bounds.minY + anchors[rowIndex + 1].bounds.maxY) / 2
                : max(page.bounds(for: .cropBox).minY, anchor.bounds.minY - 45)
            let yRange = bottom...top
            let reference = cellText(on: page, xRange: layout.referenceRange, yRange: yRange)
            let note = cellText(on: page, xRange: layout.explanationRange, yRange: yRange)
            let debitText = cellText(on: page, xRange: layout.debitRange, yRange: yRange)
            let creditText = cellText(on: page, xRange: layout.creditRange, yRange: yRange)
            let amountYRange = (anchor.bounds.minY - 4)...(anchor.bounds.maxY + 4)
            let rowAmounts = pageAmounts.filter { amountYRange.contains($0.bounds.midY) }
            let debitAmounts = rowAmounts.filter { $0.bounds.midX < layout.amountSplit }
            let creditAmounts = rowAmounts.filter { $0.bounds.midX >= layout.amountSplit }

            guard debitAmounts.count <= 1, creditAmounts.count <= 1 else {
                issues.append(.ambiguousAmount(page: pageIndex + 1, row: rowIndex + 1))
                continue
            }
            let debitAmount = debitAmounts.first?.amount
            let creditAmount = creditAmounts.first?.amount
            guard debitAmount == nil || creditAmount == nil else {
                issues.append(.ambiguousAmount(page: pageIndex + 1, row: rowIndex + 1))
                continue
            }
            guard let amount = debitAmount ?? creditAmount else {
                let issue: BankStatementIssue
                if debitText.isEmpty && creditText.isEmpty {
                    issue = .ambiguousAmount(page: pageIndex + 1, row: rowIndex + 1)
                } else {
                    issue = .invalidRow(page: pageIndex + 1, row: rowIndex + 1)
                }
                issues.append(issue)
                continue
            }
            guard !reference.isEmpty else {
                issues.append(.invalidRow(page: pageIndex + 1, row: rowIndex + 1))
                continue
            }
            let kind: TransactionKind = debitAmount == nil ? .income : .expense
            candidates.append(
                BankTransactionCandidate(
                    id: BankTransactionCandidate.makeID(
                        bank: metadata.bank,
                        accountLastFour: metadata.accountLastFour,
                        occurredAt: anchor.date,
                        kind: kind,
                        amount: amount,
                        sourceReference: reference
                    ),
                    occurredAt: anchor.date,
                    kind: kind,
                    amount: amount,
                    note: note,
                    sourceReference: reference,
                    sourcePage: pageIndex + 1
                )
            )
        }
        return (candidates, issues)
    }

    private func containsTransactionTimestamp(on page: PDFPage) -> Bool {
        (page.string ?? "").components(separatedBy: .newlines).contains {
            transactionDate(from: normalizedWhitespace($0)) != nil
        }
    }

    private func columnLayout(on page: PDFPage) throws -> ColumnLayout {
        let cropBox = page.bounds(for: .cropBox)
        let titles = ["Transaction Date", "Reference Number", "Explanation", "Debit", "Credit"]
        let headerBounds = titles.compactMap { bounds(of: $0, on: page) }
        guard headerBounds.count == titles.count else {
            throw BankStatementParserError.unrecognizedLayout
        }
        let referenceBounds = headerBounds[1]
        let debitBounds = headerBounds[3]
        let creditBounds = headerBounds[4]
        let balanceBounds = bounds(of: "Balance", on: page, closestToY: creditBounds.midY)
        let amountColumnWidth = cropBox.width * 0.10
        let debitStart = debitBounds.maxX - amountColumnWidth
        let amountSplit = (debitBounds.midX + creditBounds.midX) / 2
        let creditEnd =
            balanceBounds.flatMap {
                $0.minX > creditBounds.maxX ? (creditBounds.midX + $0.midX) / 2 : nil
            } ?? cropBox.maxX
        guard
            referenceBounds.minX < referenceBounds.maxX,
            referenceBounds.maxX < debitStart,
            debitStart < amountSplit,
            amountSplit < creditEnd,
            creditEnd <= cropBox.maxX
        else {
            throw BankStatementParserError.unrecognizedLayout
        }
        return ColumnLayout(
            dateRange: cropBox.minX...referenceBounds.minX,
            referenceRange: referenceBounds.minX...referenceBounds.maxX,
            explanationRange: referenceBounds.maxX...debitStart,
            debitRange: debitStart...amountSplit,
            creditRange: amountSplit...creditEnd,
            amountSplit: amountSplit,
            headerBottom: headerBounds.map(\.minY).min() ?? cropBox.maxY
        )
    }

    private func bounds(of text: String, on page: PDFPage) -> CGRect? {
        guard let pageText = page.string else {
            return nil
        }
        let range = (pageText as NSString).range(of: text, options: .caseInsensitive)
        guard range.location != NSNotFound, let selection = page.selection(for: range) else {
            return nil
        }
        return selection.bounds(for: page)
    }

    private func bounds(of text: String, on page: PDFPage, closestToY targetY: CGFloat) -> CGRect? {
        guard
            let pageText = page.string,
            let expression = try? NSRegularExpression(
                pattern: NSRegularExpression.escapedPattern(for: text),
                options: .caseInsensitive
            )
        else {
            return nil
        }
        let range = NSRange(pageText.startIndex..., in: pageText)
        return expression.matches(in: pageText, range: range).compactMap {
            page.selection(for: $0.range)?.bounds(for: page)
        }.min {
            abs($0.midY - targetY) < abs($1.midY - targetY)
        }
    }

    private func declaredTotals(in document: PDFDocument) -> BankStatementTotals? {
        for pageIndex in (0..<document.pageCount).reversed() {
            guard let page = document.page(at: pageIndex) else {
                continue
            }
            let footerLines = (page.string ?? "").components(separatedBy: .newlines)
            if let footer = footerLines.first(where: {
                normalized($0).contains("TOTAL AMOUNT INCURRED")
            }) {
                let values = matches(pattern: #"\b\d[\d,.]*\b"#, in: footer)
                    .compactMap { amount(from: $0, allowsZero: true) }
                if values.count == 2 {
                    return BankStatementTotals(debit: values[0], credit: values[1])
                }
            }
            guard
                let totalBounds = lowestBounds(of: "Total", on: page),
                let layout = try? columnLayout(on: page)
            else {
                continue
            }
            let yRange = (totalBounds.minY - 4)...(totalBounds.maxY + 4)
            let totals = positionedAmounts(
                on: page,
                minimumX: layout.debitRange.lowerBound,
                maximumX: layout.creditRange.upperBound,
                allowsZero: true
            ).filter { yRange.contains($0.bounds.midY) }
            let debit = totals.filter { $0.bounds.midX < layout.amountSplit }
            let credit = totals.filter { $0.bounds.midX >= layout.amountSplit }
            guard debit.count == 1, credit.count == 1 else {
                continue
            }
            return BankStatementTotals(debit: debit[0].amount, credit: credit[0].amount)
        }
        return nil
    }

    private func lowestBounds(of text: String, on page: PDFPage) -> CGRect? {
        guard
            let pageText = page.string,
            let expression = try? NSRegularExpression(
                pattern: NSRegularExpression.escapedPattern(for: text),
                options: .caseInsensitive
            )
        else {
            return nil
        }
        let range = NSRange(pageText.startIndex..., in: pageText)
        return expression.matches(in: pageText, range: range).compactMap {
            page.selection(for: $0.range)?.bounds(for: page)
        }.min { $0.minY < $1.minY }
    }

    private func positionedAmounts(
        on page: PDFPage,
        minimumX: CGFloat,
        maximumX: CGFloat,
        allowsZero: Bool = false
    ) -> [PositionedAmount] {
        guard
            let pageText = page.string,
            let expression = Self.amountExpression
        else {
            return []
        }
        let range = NSRange(pageText.startIndex..., in: pageText)
        return expression.matches(in: pageText, range: range).compactMap { match in
            guard
                let stringRange = Range(match.range, in: pageText),
                let value = amount(
                    from: normalizedWhitespace(String(pageText[stringRange])),
                    allowsZero: allowsZero
                ),
                let selection = page.selection(for: match.range)
            else {
                return nil
            }
            let bounds = selection.bounds(for: page)
            guard bounds.midX >= minimumX, bounds.midX <= maximumX else {
                return nil
            }
            return PositionedAmount(amount: value, bounds: bounds)
        }
    }

    private func accountLastFour(in document: PDFDocument, header: String) -> String? {
        let accountLine = metadataLine(
            in: header,
            containingAny: ["ACCOUNT NO", "ACCOUNT NUMBER", "SO TAI KHOAN"]
        )
        if let lastFour = accountLine.flatMap(BankStatementNormalization.accountLastFour) {
            return lastFour
        }
        guard
            let page = document.page(at: 0),
            let nameBounds = bounds(of: "Account's Name", on: page),
            let numberBounds = bounds(of: "Account's Number", on: page),
            let typeBounds = bounds(of: "Account Type", on: page)
        else {
            return nil
        }
        let lowerX = (nameBounds.midX + numberBounds.midX) / 2
        let upperX = (numberBounds.midX + typeBounds.midX) / 2
        let xRange = lowerX...upperX
        let yRange = (numberBounds.minY - 50)...(numberBounds.minY - 1)
        let value = cellText(on: page, xRange: xRange, yRange: yRange)
        return BankStatementNormalization.accountLastFour(from: value)
    }

    private func dateAnchors(on page: PDFPage, in xRange: ClosedRange<CGFloat>) -> [DateAnchor] {
        let cropBox = page.bounds(for: .cropBox)
        let area = CGRect(
            x: xRange.lowerBound,
            y: cropBox.minY,
            width: xRange.upperBound - xRange.lowerBound,
            height: cropBox.height
        )
        guard let selection = page.selection(for: area) else {
            return []
        }
        return selection.selectionsByLine().compactMap { line in
            guard
                let text = line.string,
                let date = transactionDate(from: normalizedWhitespace(text))
            else {
                return nil
            }
            return DateAnchor(date: date, bounds: line.bounds(for: page))
        }.sorted { $0.bounds.midY > $1.bounds.midY }
    }

    private func cellText(
        on page: PDFPage,
        xRange: ClosedRange<CGFloat>,
        yRange: ClosedRange<CGFloat>
    ) -> String {
        let area = CGRect(
            x: xRange.lowerBound,
            y: yRange.lowerBound,
            width: xRange.upperBound - xRange.lowerBound,
            height: yRange.upperBound - yRange.lowerBound
        )
        guard let selection = page.selection(for: area) else {
            return ""
        }
        return selection.selectionsByLine()
            .sorted { $0.bounds(for: page).midY > $1.bounds(for: page).midY }
            .compactMap(\.string)
            .map(normalizedWhitespace)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func transactionDate(from text: String) -> Date? {
        let pattern = #"^\d{2}/\d{2}/\d{4}( \d{2}:\d{2}(:\d{2})?)?$"#
        guard text.range(of: pattern, options: .regularExpression) != nil
        else {
            return nil
        }
        for format in ["dd/MM/yyyy HH:mm:ss", "dd/MM/yyyy HH:mm", "dd/MM/yyyy"] {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }
        return nil
    }

    private func amount(from text: String, allowsZero: Bool = false) -> Decimal? {
        guard text.range(of: #"^[0-9][0-9., ]*$"#, options: .regularExpression) != nil else {
            return nil
        }
        let digits = text.filter { $0 >= "0" && $0 <= "9" }
        guard
            let amount = Decimal(string: String(digits)),
            amount > 0 || (allowsZero && amount == 0)
        else {
            return nil
        }
        return amount
    }

    private func normalizedWhitespace(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func validatedDocument(from data: Data) throws -> PDFDocument {
        guard !data.isEmpty, data.count <= maximumByteCount, let document = PDFDocument(data: data)
        else {
            throw BankStatementParserError.unsupportedFormat
        }
        guard !document.isEncrypted else {
            throw BankStatementParserError.encryptedDocument
        }
        return document
    }

    private func text(from document: PDFDocument) throws -> String {
        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BankStatementParserError.missingTextLayer
        }
        return text
    }

    private func statementPeriod(in header: String) -> ClosedRange<Date>? {
        let periodText = header.components(separatedBy: .newlines)
            .filter {
                let line = normalized($0)
                return [
                    "STATEMENT PERIOD", "KY SAO KE", "FROM DATE", "TU NGAY", "TO DATE",
                    "DEN NGAY",
                ].contains(where: line.contains)
            }
            .joined(separator: " ")
        let dateStrings = matches(pattern: #"\b\d{2}/\d{2}/\d{4}\b"#, in: periodText)
        guard dateStrings.count >= 2 else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        formatter.dateFormat = "dd/MM/yyyy"
        guard
            let start = formatter.date(from: dateStrings[0]),
            let end = formatter.date(from: dateStrings[1]),
            start <= end
        else {
            return nil
        }
        return start...end
    }

    private func metadataLine(in header: String, containingAny markers: [String]) -> String? {
        header.components(separatedBy: .newlines).first {
            let line = normalized($0)
            return markers.contains(where: line.contains)
        }
    }

    private func matches(pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    private func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        ).uppercased()
    }
}

private struct ColumnLayout {
    let dateRange: ClosedRange<CGFloat>
    let referenceRange: ClosedRange<CGFloat>
    let explanationRange: ClosedRange<CGFloat>
    let debitRange: ClosedRange<CGFloat>
    let creditRange: ClosedRange<CGFloat>
    let amountSplit: CGFloat
    let headerBottom: CGFloat
}

private struct PositionedAmount {
    let amount: Decimal
    let bounds: CGRect
}

private struct DateAnchor {
    let date: Date
    let bounds: CGRect
}
