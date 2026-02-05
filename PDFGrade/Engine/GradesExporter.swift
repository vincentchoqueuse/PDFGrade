//
//  GradesExporter.swift
//  PDFGrade
//
//  Export grades to JSON and CSV formats
//

import Foundation
import UniformTypeIdentifiers

struct GradesExporter {

    // MARK: - ZIP Export (All PDFs)

    static func exportAllPDFsAsZip(copies: [CopyFeedback]) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        // Create a temporary folder for PDFs
        let pdfFolderURL = tempDir.appendingPathComponent("graded_pdfs_\(timestamp)")
        try FileManager.default.createDirectory(at: pdfFolderURL, withIntermediateDirectories: true)

        // Export each copy as PDF
        for copy in copies {
            let exportedURL = try await PDFExporter.export(copy: copy)

            // Create filename based on student name or copy ID
            let safeName = (copy.studentName ?? "copy_\(copy.id.prefix(6))")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let destFilename = "\(safeName)_graded.pdf"
            let destURL = pdfFolderURL.appendingPathComponent(destFilename)

            // Copy the exported PDF
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: exportedURL, to: destURL)
        }

        // Create ZIP using Coordinator
        let zipURL = tempDir.appendingPathComponent("graded_pdfs_\(timestamp).zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }

        try createZipFile(from: pdfFolderURL, to: zipURL)

        // Clean up temp folder
        try? FileManager.default.removeItem(at: pdfFolderURL)

        return zipURL
    }

    // Simple ZIP creation using NSFileCoordinatorReadingOptions
    private static func createZipFile(from sourceURL: URL, to destinationURL: URL) throws {
        var error: NSError?

        NSFileCoordinator().coordinate(
            readingItemAt: sourceURL,
            options: .forUploading,
            error: &error
        ) { zipURL in
            do {
                try FileManager.default.copyItem(at: zipURL, to: destinationURL)
            } catch {
                // Error handled below
            }
        }

        if let error = error {
            throw error
        }
    }

    // MARK: - JSON Export

    static func exportJSON(copies: [CopyFeedback]) async throws -> URL {
        let exportData = copies.map { copy in
            GradeExportItem(
                studentName: copy.studentName ?? "Unknown",
                studentID: copy.studentID,
                total: copy.total,
                maxTotal: copy.maxTotal,
                percentage: copy.percentage,
                isFullyGraded: copy.isFullyGraded,
                sections: copy.sections.map { section in
                    SectionExportItem(
                        name: section.name,
                        subtotal: section.subtotal,
                        maxSubtotal: section.maxSubtotal,
                        questions: section.questions.map { question in
                            QuestionExportItem(
                                name: question.name,
                                points: question.points,
                                maxPoints: question.maxPoints,
                                status: question.status.rawValue,
                                stamp: question.stampText
                            )
                        }
                    )
                },
                gradedAt: copy.updatedAt
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(exportData)

        let outputDir = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "grades_\(dateFormatter.string(from: Date())).json"
        let outputURL = outputDir.appendingPathComponent(filename)

        try data.write(to: outputURL)

        return outputURL
    }

    // MARK: - CSV Export

    static func exportCSV(copies: [CopyFeedback]) async throws -> URL {
        var csvContent = ""

        // Build header
        var headers = ["Student Name", "Student ID", "Total", "Max Total", "Percentage", "Fully Graded"]

        // Get all unique question names from the first copy with sections
        var questionNames: [String] = []
        if let firstCopyWithSections = copies.first(where: { !$0.sections.isEmpty }) {
            for section in firstCopyWithSections.sections {
                for question in section.questions {
                    questionNames.append("\(section.shortName)-\(question.shortName)")
                }
            }
        }
        headers.append(contentsOf: questionNames)

        csvContent += headers.joined(separator: ",") + "\n"

        // Build rows
        for copy in copies {
            var row: [String] = []

            // Basic info
            row.append(escapeCSV(copy.studentName ?? "Unknown"))
            row.append(escapeCSV(copy.studentID ?? ""))
            row.append(String(format: "%.2f", copy.total))
            row.append(String(format: "%.2f", copy.maxTotal))
            row.append(String(format: "%.1f", copy.percentage))
            row.append(copy.isFullyGraded ? "Yes" : "No")

            // Questions
            for section in copy.sections {
                for question in section.questions {
                    if let points = question.points {
                        row.append(String(format: "%.2f", points))
                    } else {
                        row.append("")
                    }
                }
            }

            // Pad with empty cells if this copy has fewer questions
            while row.count < headers.count {
                row.append("")
            }

            csvContent += row.joined(separator: ",") + "\n"
        }

        let outputDir = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "grades_\(dateFormatter.string(from: Date())).csv"
        let outputURL = outputDir.appendingPathComponent(filename)

        try csvContent.write(to: outputURL, atomically: true, encoding: .utf8)

        return outputURL
    }

    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
}

// MARK: - Rubric Template Export/Import

struct RubricTemplate: Codable {
    let name: String
    let createdAt: Date
    let sections: [RubricSectionTemplate]
    let maxTotal: Double

    init(name: String, sections: [Section]) {
        self.name = name
        self.createdAt = Date()
        self.sections = sections.map { RubricSectionTemplate(from: $0) }
        self.maxTotal = sections.map(\.maxSubtotal).reduce(0, +)
    }
}

struct RubricSectionTemplate: Codable {
    let name: String
    let shortName: String
    let questions: [RubricQuestionTemplate]

    init(from section: Section) {
        self.name = section.name
        self.shortName = section.shortName
        self.questions = section.questions.map { RubricQuestionTemplate(from: $0) }
    }

    func toSection() -> Section {
        Section(
            name: name,
            shortName: shortName,
            questions: questions.map { $0.toQuestion() }
        )
    }
}

struct RubricQuestionTemplate: Codable {
    let name: String
    let shortName: String
    let maxPoints: Double

    init(from question: Question) {
        self.name = question.name
        self.shortName = question.shortName
        self.maxPoints = question.maxPoints
    }

    func toQuestion() -> Question {
        Question(
            name: name,
            shortName: shortName,
            maxPoints: maxPoints
        )
    }
}

extension GradesExporter {

    // MARK: - Export Rubric

    static func exportRubric(from copy: CopyFeedback, name: String) throws -> URL {
        let template = RubricTemplate(name: name, sections: copy.sections)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(template)

        let outputDir = FileManager.default.temporaryDirectory
        let safeName = name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let filename = "rubric_\(safeName).json"
        let outputURL = outputDir.appendingPathComponent(filename)

        try data.write(to: outputURL)

        return outputURL
    }

    // MARK: - Import Rubric

    static func importRubric(from url: URL) throws -> [Section] {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let template = try decoder.decode(RubricTemplate.self, from: data)

        return template.sections.map { $0.toSection() }
    }
}

// MARK: - Export Models

struct GradeExportItem: Codable {
    let studentName: String
    let studentID: String?
    let total: Double
    let maxTotal: Double
    let percentage: Double
    let isFullyGraded: Bool
    let sections: [SectionExportItem]
    let gradedAt: Date
}

struct SectionExportItem: Codable {
    let name: String
    let subtotal: Double
    let maxSubtotal: Double
    let questions: [QuestionExportItem]
}

struct QuestionExportItem: Codable {
    let name: String
    let points: Double?
    let maxPoints: Double
    let status: String
    let stamp: String?
}
