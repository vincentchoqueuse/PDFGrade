//
//  CopyFeedback.swift
//  PDFGrade
//
//  Main model for a graded copy
//  Serialized as JSON next to the PDF
//

import Foundation

// MARK: - Relative Position on PDF

struct RelativePosition: Codable, Equatable, Hashable {
    var x: Double      // 0.0 = left, 1.0 = right
    var y: Double      // 0.0 = bottom (PDF coords), 1.0 = top
    var page: Int      // Page index (0-based)

    static let zero = RelativePosition(x: 0, y: 0, page: 0)
}

// MARK: - Stamp Color

enum StampColor: String, Codable, CaseIterable {
    case green
    case yellow
    case red

    var hex: String {
        switch self {
        case .green: return "#34C759"
        case .yellow: return "#FF9500"
        case .red: return "#FF3B30"
        }
    }

    var label: String {
        switch self {
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .red: return "Red"
        }
    }
}

// MARK: - Stamp Definition (global, shared between copies)

struct StampDefinition: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var text: String
    var color: StampColor
    var coefficient: Double  // Multiplier for maxPoints (0.0 to 1.0)

    init(id: String = UUID().uuidString, text: String, color: StampColor, coefficient: Double = 1.0) {
        self.id = id
        self.text = text
        self.color = color
        self.coefficient = coefficient
    }

    // Default stamps
    static let defaults: [StampDefinition] = [
        StampDefinition(id: "default-ok", text: "Correct", color: .green, coefficient: 1.0),
        StampDefinition(id: "default-calc-error", text: "Calculation Error", color: .yellow, coefficient: 0.5),
        StampDefinition(id: "default-wrong", text: "Wrong", color: .red, coefficient: 0),
        StampDefinition(id: "default-off-topic", text: "Off Topic", color: .yellow, coefficient: 0),
        StampDefinition(id: "default-incomplete", text: "Incomplete", color: .yellow, coefficient: 0.5),
    ]
}

// MARK: - Annotation on PDF (stamp or free text)

struct Annotation: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var position: RelativePosition
    var content: AnnotationContent

    init(id: String = UUID().uuidString, position: RelativePosition, content: AnnotationContent) {
        self.id = id
        self.position = position
        self.content = content
    }
}

enum AnnotationContent: Codable, Equatable, Hashable {
    case text(String)                      // Free text
    case stamp(definitionID: String, text: String, color: StampColor)  // Stamp
    case drawing(data: Data, bounds: DrawingBounds)  // PencilKit drawing

    var isText: Bool {
        if case .text = self { return true }
        return false
    }

    var isDrawing: Bool {
        if case .drawing = self { return true }
        return false
    }
}

// MARK: - Drawing Bounds (for storing drawing region)

struct DrawingBounds: Codable, Equatable, Hashable {
    var x: Double      // Relative x (0-1)
    var y: Double      // Relative y (0-1)
    var width: Double  // Relative width
    var height: Double // Relative height
}

// MARK: - Question Status

enum QuestionStatus: String, Codable, CaseIterable {
    case pending    // Not graded (gray)
    case wrong      // Wrong (red) - 0 points
    case partial    // Partial (yellow) - 50% of points
    case correct    // Correct (green) - 100% of points

    var color: String {
        switch self {
        case .pending: return "#8E8E93"   // Gray
        case .wrong: return "#FF5F56"     // macOS Red (close)
        case .partial: return "#FFBD2E"   // macOS Yellow (minimize)
        case .correct: return "#27C93F"   // macOS Green (maximize)
        }
    }

    var icon: String {
        switch self {
        case .pending: return "circle"
        case .wrong: return "xmark.circle.fill"
        case .partial: return "minus.circle.fill"
        case .correct: return "checkmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .pending: return "-"
        case .wrong: return "✗"
        case .partial: return "~"
        case .correct: return "✓"
        }
    }

    func pointsFor(maxPoints: Double) -> Double? {
        switch self {
        case .pending: return nil
        case .wrong: return 0
        case .partial: return maxPoints / 2
        case .correct: return maxPoints
        }
    }
}

// MARK: - Question

struct Question: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var shortName: String
    var maxPoints: Double
    var points: Double?              // nil = not graded yet
    var status: QuestionStatus       // Question status
    var position: RelativePosition?  // Grade position on the PDF
    var stampText: String?           // Associated stamp (e.g., "Calculation Error")
    var stampColor: StampColor?      // Stamp color

    init(
        id: String = UUID().uuidString,
        name: String,
        shortName: String? = nil,
        maxPoints: Double,
        points: Double? = nil,
        status: QuestionStatus = .pending,
        position: RelativePosition? = nil,
        stampText: String? = nil,
        stampColor: StampColor? = nil
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName ?? String(name.prefix(3)).uppercased()
        self.maxPoints = maxPoints
        self.points = points
        self.status = status
        self.position = position
        self.stampText = stampText
        self.stampColor = stampColor
    }

    var isGraded: Bool { status != .pending }
    var hasStamp: Bool { stampText != nil }
}

// MARK: - Section

struct Section: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var shortName: String
    var position: RelativePosition?  // Pour afficher le sous-total
    var questions: [Question]

    init(
        id: String = UUID().uuidString,
        name: String,
        shortName: String? = nil,
        position: RelativePosition? = nil,
        questions: [Question] = []
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName ?? String(name.prefix(1)).uppercased()
        self.position = position
        self.questions = questions
    }

    // Calculs automatiques
    var subtotal: Double {
        questions.compactMap(\.points).reduce(0, +)
    }

    var maxSubtotal: Double {
        questions.map(\.maxPoints).reduce(0, +)
    }

    var isFullyGraded: Bool {
        questions.allSatisfy(\.isGraded)
    }
}

// MARK: - CopyFeedback (le modèle principal)

struct CopyFeedback: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var pdfPath: String
    var studentName: String?
    var studentID: String?
    var sections: [Section]
    var annotations: [Annotation]    // Stamps and free texts
    var totalPosition: RelativePosition?  // Final grade position on the PDF
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        pdfPath: String,
        studentName: String? = nil,
        studentID: String? = nil,
        sections: [Section] = [],
        annotations: [Annotation] = [],
        totalPosition: RelativePosition? = nil
    ) {
        self.id = id
        self.pdfPath = pdfPath
        self.studentName = studentName
        self.studentID = studentID
        self.sections = sections
        self.annotations = annotations
        self.totalPosition = totalPosition
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Calculs

    var total: Double {
        sections.map(\.subtotal).reduce(0, +)
    }

    var maxTotal: Double {
        sections.map(\.maxSubtotal).reduce(0, +)
    }

    var percentage: Double {
        guard maxTotal > 0 else { return 0 }
        return (total / maxTotal) * 100
    }

    var isFullyGraded: Bool {
        sections.allSatisfy(\.isFullyGraded)
    }

    var allQuestions: [Question] {
        sections.flatMap(\.questions)
    }

    // MARK: - Mutations

    mutating func setPoints(questionID: String, points: Double?) {
        for sectionIndex in sections.indices {
            if let questionIndex = sections[sectionIndex].questions.firstIndex(where: { $0.id == questionID }) {
                sections[sectionIndex].questions[questionIndex].points = points
                updatedAt = Date()
                return
            }
        }
    }

    mutating func setQuestionPosition(questionID: String, position: RelativePosition) {
        for sectionIndex in sections.indices {
            if let questionIndex = sections[sectionIndex].questions.firstIndex(where: { $0.id == questionID }) {
                sections[sectionIndex].questions[questionIndex].position = position
                updatedAt = Date()
                return
            }
        }
    }

    mutating func addAnnotation(_ annotation: Annotation) {
        annotations.append(annotation)
        updatedAt = Date()
    }

    mutating func removeAnnotation(id: String) {
        annotations.removeAll { $0.id == id }
        updatedAt = Date()
    }

    mutating func setTotalPosition(_ position: RelativePosition?) {
        totalPosition = position
        updatedAt = Date()
    }

    mutating func setSectionPosition(sectionID: String, position: RelativePosition?) {
        if let index = sections.firstIndex(where: { $0.id == sectionID }) {
            sections[index].position = position
            updatedAt = Date()
        }
    }

    // MARK: - JSON Path

    var jsonPath: String {
        pdfPath.replacingOccurrences(of: ".pdf", with: ".json")
    }

    var jsonURL: URL {
        URL(fileURLWithPath: jsonPath)
    }

    var pdfURL: URL {
        URL(fileURLWithPath: pdfPath)
    }
}

// MARK: - CopyFeedback + Persistence

extension CopyFeedback {

    static func load(from url: URL) throws -> CopyFeedback {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CopyFeedback.self, from: data)
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        try data.write(to: jsonURL)
    }

    static func loadOrCreate(pdfPath: String, template: FeedbackTemplate? = nil) -> CopyFeedback {
        let jsonPath = pdfPath.replacingOccurrences(of: ".pdf", with: ".json")
        let jsonURL = URL(fileURLWithPath: jsonPath)

        if FileManager.default.fileExists(atPath: jsonPath),
           let feedback = try? load(from: jsonURL) {
            return feedback
        }

        // Create with template if provided
        if let template = template {
            return CopyFeedback(
                pdfPath: pdfPath,
                sections: template.sections
            )
        }

        return CopyFeedback(pdfPath: pdfPath)
    }
}

// MARK: - Template (base structure to apply to all copies)

struct FeedbackTemplate: Codable {
    var name: String
    var sections: [Section]

    init(name: String, sections: [Section] = []) {
        self.name = name
        self.sections = sections
    }

    static func load(from url: URL) throws -> FeedbackTemplate {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FeedbackTemplate.self, from: data)
    }

    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
}
