//
//  PDFExporter.swift
//  PDFGrade
//
//  Export graded PDF with annotations baked in
//

import Foundation
import PDFKit
import UIKit
import PencilKit

struct PDFExporter {

    /// Export a graded copy to a new PDF with annotations rendered
    static func export(copy: CopyFeedback) async throws -> URL {
        let sourceURL = copy.pdfURL

        // Request access to security-scoped resource if needed
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ExportError.fileNotFound
        }

        guard let document = PDFDocument(url: sourceURL) else {
            throw ExportError.invalidSource
        }

        // Create output URL in Documents directory (always writable)
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let outputURL = documentsDir.appendingPathComponent("\(baseName)_graded.pdf")

        // Create PDF renderer
        let renderer = UIGraphicsPDFRenderer(bounds: .zero)

        let data = renderer.pdfData { context in
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }

                let bounds = page.bounds(for: .mediaBox)

                // Begin page with correct size
                context.beginPage(withBounds: bounds, pageInfo: [:])

                let cgContext = context.cgContext

                // Draw original PDF page
                cgContext.saveGState()

                // PDF pages are drawn with origin at bottom-left
                // We need to flip the context to draw the page correctly
                cgContext.translateBy(x: 0, y: bounds.height)
                cgContext.scaleBy(x: 1, y: -1)

                if let pageRef = page.pageRef {
                    cgContext.drawPDFPage(pageRef)
                }

                cgContext.restoreGState()

                // Draw annotations (UIKit coordinates: origin at top-left)
                drawAnnotations(copy: copy, pageIndex: pageIndex, pageSize: bounds.size)
            }
        }

        // Write to file
        do {
            try data.write(to: outputURL)
        } catch {
            throw ExportError.saveFailed
        }

        return outputURL
    }

    // MARK: - Drawing

    private static func drawAnnotations(copy: CopyFeedback, pageIndex: Int, pageSize: CGSize) {
        // Draw total badge
        if let pos = copy.totalPosition, pos.page == pageIndex {
            let point = CGPoint(
                x: pos.x * pageSize.width,
                y: (1 - pos.y) * pageSize.height
            )
            drawTotalBadge(
                total: copy.total,
                maxTotal: copy.maxTotal,
                percentage: copy.percentage,
                date: copy.updatedAt,
                at: point
            )
        }

        // Draw section badges
        for section in copy.sections {
            if let pos = section.position, pos.page == pageIndex {
                let point = CGPoint(
                    x: pos.x * pageSize.width,
                    y: (1 - pos.y) * pageSize.height
                )
                drawSectionBadge(section: section, at: point)
            }
        }

        // Draw question badges
        for question in copy.allQuestions {
            if let pos = question.position, pos.page == pageIndex {
                let point = CGPoint(
                    x: pos.x * pageSize.width,
                    y: (1 - pos.y) * pageSize.height
                )
                drawQuestionBadge(question: question, at: point)
            }
        }

        // Draw annotations (stamps and texts)
        for annotation in copy.annotations {
            if annotation.position.page == pageIndex {
                let point = CGPoint(
                    x: annotation.position.x * pageSize.width,
                    y: (1 - annotation.position.y) * pageSize.height
                )
                drawAnnotation(annotation: annotation, at: point, pageSize: pageSize)
            }
        }
    }

    private static func drawTotalBadge(total: Double, maxTotal: Double, percentage: Double, date: Date, at point: CGPoint) {
        let scoreText = "\(NumberFormatter.format(total))/\(NumberFormatter.format(maxTotal))"
        let percentText = "\(Int(percentage))%"
        let titleText = "FINAL"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let dateText = dateFormatter.string(from: date)

        let redColor = UIColor.systemRed

        let titleFont = UIFont.systemFont(ofSize: 10, weight: .bold)
        let scoreFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let percentFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let dateFont = UIFont.systemFont(ofSize: 9)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: redColor,
            .kern: 0.5
        ]
        let scoreAttrs: [NSAttributedString.Key: Any] = [.font: scoreFont, .foregroundColor: redColor]
        let percentAttrs: [NSAttributedString.Key: Any] = [.font: percentFont, .foregroundColor: redColor.withAlphaComponent(0.8)]
        let dateAttrs: [NSAttributedString.Key: Any] = [.font: dateFont, .foregroundColor: redColor.withAlphaComponent(0.6)]

        let titleSize = titleText.size(withAttributes: titleAttrs)
        let scoreSize = scoreText.size(withAttributes: scoreAttrs)
        let percentSize = percentText.size(withAttributes: percentAttrs)
        let dateSize = dateText.size(withAttributes: dateAttrs)

        // Horizontal layout
        let hPadding: CGFloat = 14
        let vPadding: CGFloat = 8
        let spacing: CGFloat = 12
        let dividerWidth: CGFloat = 1
        let dividerHeight: CGFloat = 24

        let badgeWidth = hPadding + titleSize.width + spacing + dividerWidth + spacing + scoreSize.width + spacing + percentSize.width + spacing + dividerWidth + spacing + dateSize.width + hPadding
        let badgeHeight = max(scoreSize.height, dividerHeight) + vPadding * 2

        let badgeRect = CGRect(
            x: point.x - badgeWidth / 2,
            y: point.y - badgeHeight / 2,
            width: badgeWidth,
            height: badgeHeight
        )

        // Shadow
        let shadowPath = UIBezierPath(roundedRect: badgeRect.offsetBy(dx: 0, dy: 1), cornerRadius: 6)
        UIColor.black.withAlphaComponent(0.2).setFill()
        shadowPath.fill()

        // Background
        let bgPath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 6)
        UIColor.white.setFill()
        bgPath.fill()

        // Red border
        redColor.setStroke()
        bgPath.lineWidth = 2
        bgPath.stroke()

        // Draw elements horizontally
        var xOffset = badgeRect.minX + hPadding
        let centerY = badgeRect.midY

        // Title
        let titlePoint = CGPoint(x: xOffset, y: centerY - titleSize.height / 2)
        titleText.draw(at: titlePoint, withAttributes: titleAttrs)
        xOffset += titleSize.width + spacing

        // Divider 1
        let divider1Rect = CGRect(x: xOffset, y: centerY - dividerHeight / 2, width: dividerWidth, height: dividerHeight)
        redColor.withAlphaComponent(0.3).setFill()
        UIBezierPath(rect: divider1Rect).fill()
        xOffset += dividerWidth + spacing

        // Score
        let scorePoint = CGPoint(x: xOffset, y: centerY - scoreSize.height / 2)
        scoreText.draw(at: scorePoint, withAttributes: scoreAttrs)
        xOffset += scoreSize.width + spacing

        // Percentage with background
        let percentBgRect = CGRect(x: xOffset - 4, y: centerY - percentSize.height / 2 - 2, width: percentSize.width + 8, height: percentSize.height + 4)
        redColor.withAlphaComponent(0.1).setFill()
        UIBezierPath(roundedRect: percentBgRect, cornerRadius: percentBgRect.height / 2).fill()
        let percentPoint = CGPoint(x: xOffset, y: centerY - percentSize.height / 2)
        percentText.draw(at: percentPoint, withAttributes: percentAttrs)
        xOffset += percentSize.width + spacing + 4

        // Divider 2
        let divider2Rect = CGRect(x: xOffset, y: centerY - dividerHeight / 2, width: dividerWidth, height: dividerHeight)
        redColor.withAlphaComponent(0.3).setFill()
        UIBezierPath(rect: divider2Rect).fill()
        xOffset += dividerWidth + spacing

        // Date
        let datePoint = CGPoint(x: xOffset, y: centerY - dateSize.height / 2)
        dateText.draw(at: datePoint, withAttributes: dateAttrs)
    }

    private static func drawSectionBadge(section: Section, at point: CGPoint) {
        let titleText = "Subscore: \(section.name)"
        let scoreText = "\(NumberFormatter.format(section.subtotal))/\(NumberFormatter.format(section.maxSubtotal))"

        let redColor = UIColor.systemRed

        let titleFont = UIFont.systemFont(ofSize: 7, weight: .medium)
        let scoreFont = UIFont.systemFont(ofSize: 12, weight: .bold)

        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: redColor.withAlphaComponent(0.8)]
        let scoreAttrs: [NSAttributedString.Key: Any] = [.font: scoreFont, .foregroundColor: redColor]

        let titleSize = titleText.size(withAttributes: titleAttrs)
        let scoreSize = scoreText.size(withAttributes: scoreAttrs)

        let padding: CGFloat = 8
        let spacing: CGFloat = 2
        let maxWidth = max(titleSize.width, scoreSize.width)
        let badgeWidth = maxWidth + padding * 2
        let badgeHeight = titleSize.height + scoreSize.height + spacing + padding * 2

        let badgeRect = CGRect(
            x: point.x - badgeWidth / 2,
            y: point.y - badgeHeight / 2,
            width: badgeWidth,
            height: badgeHeight
        )

        // Shadow
        let shadowPath = UIBezierPath(roundedRect: badgeRect.offsetBy(dx: 0, dy: 1), cornerRadius: 4)
        UIColor.black.withAlphaComponent(0.1).setFill()
        shadowPath.fill()

        // Background
        let bgPath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 4)
        UIColor.white.setFill()
        bgPath.fill()

        // Red border
        redColor.setStroke()
        bgPath.lineWidth = 1.5
        bgPath.stroke()

        // Draw texts centered
        var yOffset = badgeRect.minY + padding

        let titlePoint = CGPoint(x: badgeRect.midX - titleSize.width / 2, y: yOffset)
        titleText.draw(at: titlePoint, withAttributes: titleAttrs)
        yOffset += titleSize.height + spacing

        let scorePoint = CGPoint(x: badgeRect.midX - scoreSize.width / 2, y: yOffset)
        scoreText.draw(at: scorePoint, withAttributes: scoreAttrs)
    }

    private static func drawQuestionBadge(question: Question, at point: CGPoint) {
        let scoreText = "\(NumberFormatter.format(question.points ?? 0))/\(NumberFormatter.format(question.maxPoints))"
        let stampText = question.stampText

        let redColor = UIColor.systemRed

        let scoreFont = UIFont.systemFont(ofSize: 10, weight: .bold)
        let stampFont = UIFont.systemFont(ofSize: 7, weight: .medium)

        let scoreAttrs: [NSAttributedString.Key: Any] = [.font: scoreFont, .foregroundColor: redColor]
        let stampAttrs: [NSAttributedString.Key: Any] = [.font: stampFont, .foregroundColor: redColor.withAlphaComponent(0.8)]

        let scoreSize = scoreText.size(withAttributes: scoreAttrs)
        let stampSize = stampText?.size(withAttributes: stampAttrs) ?? .zero

        let padding: CGFloat = 6
        let pillSize: CGFloat = 6
        let spacing: CGFloat = 5

        // Pill color
        let pillColor: UIColor = {
            if let stampColor = question.stampColor {
                return UIColor(hex: stampColor.hex)
            } else {
                return UIColor(hex: question.status.color)
            }
        }()

        // Score box dimensions
        let boxWidth = scoreSize.width + spacing + pillSize + padding * 2
        let boxHeight = scoreSize.height + padding * 2

        // Calculate total height including stamp below
        let stampSpacing: CGFloat = 3
        let totalHeight = stampText != nil ? boxHeight + stampSpacing + stampSize.height : boxHeight

        let badgeRect = CGRect(
            x: point.x - boxWidth / 2,
            y: point.y - totalHeight / 2,
            width: boxWidth,
            height: boxHeight
        )

        // Shadow
        let shadowPath = UIBezierPath(roundedRect: badgeRect.offsetBy(dx: 0, dy: 1), cornerRadius: 4)
        UIColor.black.withAlphaComponent(0.1).setFill()
        shadowPath.fill()

        // Background
        let bgPath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 4)
        UIColor.white.setFill()
        bgPath.fill()

        // Red border
        redColor.setStroke()
        bgPath.lineWidth = 1.5
        bgPath.stroke()

        // Score text
        let scorePoint = CGPoint(x: badgeRect.minX + padding, y: badgeRect.minY + padding)
        scoreText.draw(at: scorePoint, withAttributes: scoreAttrs)

        // Color pill (right of score)
        let pillRect = CGRect(
            x: badgeRect.minX + padding + scoreSize.width + spacing,
            y: badgeRect.midY - pillSize / 2,
            width: pillSize,
            height: pillSize
        )
        pillColor.setFill()
        UIBezierPath(ovalIn: pillRect).fill()

        // Stamp text below (if present)
        if let stamp = stampText {
            let stampPoint = CGPoint(
                x: point.x - stampSize.width / 2,
                y: badgeRect.maxY + stampSpacing
            )
            stamp.draw(at: stampPoint, withAttributes: stampAttrs)
        }
    }

    private static func drawAnnotation(annotation: Annotation, at point: CGPoint, pageSize: CGSize) {
        switch annotation.content {
        case .text(let text):
            let font = UIFont.systemFont(ofSize: 9)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]

            let textSize = text.size(withAttributes: attributes)
            let padding: CGFloat = 4
            let badgeRect = CGRect(
                x: point.x - (textSize.width + padding * 2) / 2,
                y: point.y - (textSize.height + padding * 2) / 2,
                width: textSize.width + padding * 2,
                height: textSize.height + padding * 2
            )

            // Shadow
            let shadowPath = UIBezierPath(roundedRect: badgeRect.offsetBy(dx: 0, dy: 1), cornerRadius: 3)
            UIColor.black.withAlphaComponent(0.1).setFill()
            shadowPath.fill()

            // Yellow background
            let bgPath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 3)
            UIColor.systemYellow.withAlphaComponent(0.9).setFill()
            bgPath.fill()

            // Text
            let textPoint = CGPoint(x: badgeRect.minX + padding, y: badgeRect.minY + padding)
            text.draw(at: textPoint, withAttributes: attributes)

        case .stamp(_, let text, let color):
            let font = UIFont.systemFont(ofSize: 9, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]

            let textSize = text.size(withAttributes: attributes)
            let padding: CGFloat = 5
            let badgeRect = CGRect(
                x: point.x - (textSize.width + padding * 2) / 2,
                y: point.y - (textSize.height + padding * 2) / 2,
                width: textSize.width + padding * 2,
                height: textSize.height + padding * 2
            )

            // Shadow
            let shadowPath = UIBezierPath(roundedRect: badgeRect.offsetBy(dx: 0, dy: 1), cornerRadius: 3)
            UIColor.black.withAlphaComponent(0.15).setFill()
            shadowPath.fill()

            // Colored background
            let bgPath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 3)
            UIColor(hex: color.hex).setFill()
            bgPath.fill()

            // Text
            let textPoint = CGPoint(x: badgeRect.minX + padding, y: badgeRect.minY + padding)
            text.draw(at: textPoint, withAttributes: attributes)

        case .drawing(let data, let bounds):
            // Draw PencilKit drawing
            if let drawing = try? PKDrawing(data: data) {
                let drawingBounds = drawing.bounds
                let image = drawing.image(from: drawingBounds, scale: 2.0)

                // Calculate position on page
                let rect = CGRect(
                    x: bounds.x * pageSize.width,
                    y: (1 - bounds.y - bounds.height) * pageSize.height,
                    width: bounds.width * pageSize.width,
                    height: bounds.height * pageSize.height
                )

                image.draw(in: rect)
            }
        }
    }
}

// MARK: - UIColor hex extension

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - Export Error

enum ExportError: LocalizedError {
    case fileNotFound
    case invalidSource
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "PDF file not found. It may have been moved or deleted."
        case .invalidSource: return "Cannot read source PDF. The file may be corrupted."
        case .saveFailed: return "Failed to save exported PDF."
        }
    }
}
