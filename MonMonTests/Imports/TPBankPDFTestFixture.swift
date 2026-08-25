import CoreGraphics
import CoreText
import Foundation

enum TPBankPDFTestFixture {
    struct Row {
        let date: String
        let reference: String
        let noteLines: [String]
        let debit: String?
        let credit: String?
    }

    struct Totals {
        let debit: String
        let credit: String
    }

    static func statement(
        includeColumns: Bool = true,
        includeMetadata: Bool = true,
        rows: [Row] = [],
        declaredTotals: Totals? = nil,
        password: String? = nil
    ) -> Data {
        pdf(
            pages: [
                pageCells(
                    includeColumns: includeColumns,
                    includeMetadata: includeMetadata,
                    rows: rows,
                    declaredTotals: declaredTotals,
                    pageNumber: 1,
                    pageCount: 1
                )
            ],
            password: password
        )
    }

    static func statement(pages: [[Row]], declaredTotals: Totals) -> Data {
        pdf(
            pages: pages.enumerated().map { index, rows in
                pageCells(
                    includeColumns: true,
                    includeMetadata: true,
                    rows: rows,
                    declaredTotals: index == pages.count - 1 ? declaredTotals : nil,
                    pageNumber: index + 1,
                    pageCount: pages.count
                )
            }
        )
    }

    static func extractionConfirmationStatement(rows: [Row], declaredTotals: Totals) -> Data {
        var cells = [
            Cell("TPBANK - TIEN PHONG COMMERCIAL JOINT STOCK BANK", x: 40, y: 800),
            Cell(
                "XAC NHAN TRICH DAN SAO KE / STATEMENT EXTRACTION CONFIRMATION",
                x: 40,
                y: 776
            ),
            Cell("Tu ngay/From: 01/05/2026 Den ngay/To: 31/07/2026", x: 40, y: 752),
            Cell("Account's Name", x: 40, y: 728),
            Cell("Account's Number", x: 190, y: 728),
            Cell("Account Type", x: 350, y: 728),
            Cell("Currency", x: 485, y: 728),
            Cell("Synthetic Owner", x: 40, y: 704),
            Cell("1111 2222 3333", x: 190, y: 704),
            Cell("Payment", x: 350, y: 704),
            Cell("VND", x: 485, y: 704),
            Cell("Transaction Date", x: 35, y: 660),
            Cell("Reference Number", x: 145, y: 660),
            Cell("Explanation", x: 275, y: 660),
            Cell("Debit", x: 460, y: 660),
            Cell("Credit", x: 525, y: 660),
        ]
        for (index, row) in rows.enumerated() {
            let y = 625 - CGFloat(index * 55)
            cells += rowCells(row, at: y)
        }
        let totalY = 625 - CGFloat(rows.count * 55) - 20
        cells += [
            Cell("Total Amount Incurred", x: 275, y: totalY),
            Cell(declaredTotals.debit, x: 460, y: totalY),
            Cell(declaredTotals.credit, x: 525, y: totalY),
        ]
        return pdf(pages: [cells])
    }

    private static func pageCells(
        includeColumns: Bool,
        includeMetadata: Bool,
        rows: [Row],
        declaredTotals: Totals?,
        pageNumber: Int,
        pageCount: Int
    ) -> [Cell] {
        var cells = [
            Cell("TPBANK - TIEN PHONG COMMERCIAL JOINT STOCK BANK", x: 40, y: 800),
            Cell("SAO KE TAI KHOAN / ACCOUNT STATEMENT", x: 40, y: 776),
        ]
        if includeMetadata {
            cells += [
                Cell("Account No. / So tai khoan: 1234 5678 9012", x: 40, y: 752),
                Cell("Statement period / Ky sao ke: 01/05/2026 - 31/07/2026", x: 40, y: 728),
                Cell("Currency / Loai tien: VND", x: 40, y: 704),
            ]
        }
        if includeColumns {
            cells += [
                Cell("Transaction Date", x: 35, y: 660),
                Cell("Reference Number", x: 145, y: 660),
                Cell("Explanation", x: 275, y: 660),
                Cell("Debit", x: 460, y: 660),
                Cell("Credit", x: 525, y: 660),
            ]
        }
        for (index, row) in rows.enumerated() {
            let y = 625 - CGFloat(index * 55)
            cells += rowCells(row, at: y)
        }
        if let declaredTotals {
            let y = 625 - CGFloat(rows.count * 55) - 20
            cells += [
                Cell("Total", x: 275, y: y),
                Cell(declaredTotals.debit, x: 460, y: y),
                Cell(declaredTotals.credit, x: 525, y: y),
            ]
        }
        cells.append(Cell("Page \(pageNumber) / \(pageCount)", x: 275, y: 30))
        return cells
    }

    private static func rowCells(_ row: Row, at y: CGFloat) -> [Cell] {
        var cells = [
            Cell(row.date, x: 35, y: y),
            Cell(row.reference, x: 145, y: y),
        ]
        cells += row.noteLines.enumerated().map {
            Cell($0.element, x: 250, y: y - CGFloat($0.offset * 13))
        }
        if let debit = row.debit {
            cells.append(Cell(debit, x: 460, y: y))
        }
        if let credit = row.credit {
            cells.append(Cell(credit, x: 525, y: y))
        }
        return cells
    }

    static func unrelatedStatement() -> Data {
        pdf(pages: [[Cell("FAKE BANK Monthly activity statement", x: 40, y: 800)]])
    }

    static func imageOnlyStatement() -> Data {
        pdf(pages: [[]])
    }

    private struct Cell {
        let text: String
        let point: CGPoint

        init(_ text: String, x: CGFloat, y: CGFloat) {
            self.text = text
            point = CGPoint(x: x, y: y)
        }
    }

    private static func pdf(pages: [[Cell]], password: String? = nil) -> Data {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else {
            preconditionFailure("Unable to create the synthetic PDF data consumer")
        }
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        let options: CFDictionary? = password.map {
            [
                kCGPDFContextOwnerPassword: $0,
                kCGPDFContextUserPassword: $0,
            ] as CFDictionary
        }
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, options) else {
            preconditionFailure("Unable to create the synthetic PDF context")
        }

        for cells in pages {
            context.beginPDFPage(nil)
            context.textMatrix = .identity
            for cell in cells {
                draw(cell.text, at: cell.point, in: context)
            }
            context.endPDFPage()
        }
        context.closePDF()
        return output as Data
    }

    private static func draw(_ text: String, at point: CGPoint, in context: CGContext) {
        let font = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
        let attributes = [
            NSAttributedString.Key(kCTFontAttributeName as String): font
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )
        context.textPosition = point
        CTLineDraw(line, context)
    }
}
