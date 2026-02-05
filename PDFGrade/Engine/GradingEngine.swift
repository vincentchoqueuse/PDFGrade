//
//  GradingEngine.swift
//  PDFGrade
//
//  @Observable data engine for global reactivity
//

import Foundation
import Observation
import SwiftUI

@Observable
final class GradingEngine {
    // MARK: - Main State

    var copies: [CopyFeedback] = []
    var selectedCopyID: String?

    // Global stamps (shared between all copies)
    var stampDefinitions: [StampDefinition] = StampDefinition.defaults

    // Element being positioned
    var positioningElement: PositionableElement?

    // Selected tool
    var selectedTool: Tool = .select

    // Selected stamp for placement
    var selectedStamp: StampDefinition?

    // Currently selected annotation (for editing/moving/deleting)
    var selectedAnnotationID: String?

    // Annotation being edited inline (ID)
    var inlineEditingAnnotationID: String?

    // Computed property for selected annotation
    var selectedAnnotation: Annotation? {
        guard let id = selectedAnnotationID,
              let copy = currentCopy else { return nil }
        return copy.annotations.first { $0.id == id }
    }

    // Create a new text annotation and start inline editing
    func createAndEditTextAnnotation(at position: RelativePosition) {
        let annotation = Annotation(position: position, content: .text(""))
        guard let index = currentCopyIndex else { return }
        copies[index].annotations.append(annotation)
        copies[index].updatedAt = Date()
        inlineEditingAnnotationID = annotation.id
    }

    // Finish inline editing
    func finishInlineEditing() {
        guard let editingID = inlineEditingAnnotationID,
              let index = currentCopyIndex else { return }

        // Remove if empty
        if let annotation = copies[index].annotations.first(where: { $0.id == editingID }),
           case .text(let text) = annotation.content,
           text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copies[index].annotations.removeAll { $0.id == editingID }
        }

        inlineEditingAnnotationID = nil
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    // Sidebar tab
    var sidebarTab: SidebarTab = .evaluation

    // MARK: - Current Copy

    var currentCopy: CopyFeedback? {
        get {
            guard let id = selectedCopyID else { return nil }
            return copies.first { $0.id == id }
        }
        set {
            guard let newValue = newValue,
                  let index = copies.firstIndex(where: { $0.id == newValue.id }) else { return }
            copies[index] = newValue
        }
    }

    var currentCopyIndex: Int? {
        guard let id = selectedCopyID else { return nil }
        return copies.firstIndex { $0.id == id }
    }

    // MARK: - Save Error

    var saveError: Error?

    // MARK: - Question Lookup Helper

    /// Finds the location of a question by its ID
    /// - Parameter questionID: The ID of the question to find
    /// - Returns: A tuple containing the section and question indices, or nil if not found
    private func findQuestionLocation(questionID: String, in copyIndex: Int) -> (sectionIndex: Int, questionIndex: Int)? {
        for sectionIndex in copies[copyIndex].sections.indices {
            if let questionIndex = copies[copyIndex].sections[sectionIndex].questions.firstIndex(where: { $0.id == questionID }) {
                return (sectionIndex, questionIndex)
            }
        }
        return nil
    }

    // MARK: - Mutations sur la copie courante

    func setStudentName(_ name: String?) {
        guard let index = currentCopyIndex else { return }
        copies[index].studentName = name?.isEmpty == true ? nil : name
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    func setPoints(questionID: String, points: Double?) {
        guard let index = currentCopyIndex else { return }
        copies[index].setPoints(questionID: questionID, points: points)
        saveCurrent()
    }

    func setQuestionStatus(questionID: String, status: QuestionStatus) {
        guard let index = currentCopyIndex,
              let loc = findQuestionLocation(questionID: questionID, in: index) else { return }
        let maxPoints = copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].maxPoints
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].status = status
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].points = status.pointsFor(maxPoints: maxPoints)
        // Clear stamp if manually changing status
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].stampText = nil
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].stampColor = nil
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    func setQuestionStamp(questionID: String, stamp: StampDefinition) {
        guard let index = currentCopyIndex,
              let loc = findQuestionLocation(questionID: questionID, in: index) else { return }
        let maxPoints = copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].maxPoints

        // Calculate points using the stamp coefficient
        let points = maxPoints * stamp.coefficient

        // Determine status based on coefficient
        let status: QuestionStatus
        if stamp.coefficient >= 1.0 {
            status = .correct
        } else if stamp.coefficient > 0 {
            status = .partial
        } else {
            status = .wrong
        }

        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].status = status
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].points = points
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].stampText = stamp.text
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].stampColor = stamp.color
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    func clearQuestionStamp(questionID: String) {
        guard let index = currentCopyIndex,
              let loc = findQuestionLocation(questionID: questionID, in: index) else { return }
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].stampText = nil
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].stampColor = nil
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    func setQuestionPosition(questionID: String, position: RelativePosition?) {
        guard let index = currentCopyIndex,
              let loc = findQuestionLocation(questionID: questionID, in: index) else { return }
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].position = position
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    func setSectionPosition(sectionID: String, position: RelativePosition?) {
        guard let index = currentCopyIndex else { return }
        if let sectionIndex = copies[index].sections.firstIndex(where: { $0.id == sectionID }) {
            copies[index].sections[sectionIndex].position = position
            copies[index].updatedAt = Date()
            saveCurrent()
        }
    }

    func setTotalPosition(_ position: RelativePosition?) {
        guard let index = currentCopyIndex else { return }
        copies[index].totalPosition = position
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    // MARK: - Rubric (structure)

    func addSection(name: String? = nil) {
        guard let index = currentCopyIndex else { return }
        let sectionNumber = copies[index].sections.count + 1
        let sectionName = name ?? "Section \(sectionNumber)"
        let newSection = Section(
            name: sectionName,
            shortName: "S\(sectionNumber)"
        )
        copies[index].sections.append(newSection)
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    func updateSection(sectionID: String, name: String, shortName: String) {
        guard let index = currentCopyIndex else { return }
        if let sectionIndex = copies[index].sections.firstIndex(where: { $0.id == sectionID }) {
            copies[index].sections[sectionIndex].name = name
            copies[index].sections[sectionIndex].shortName = shortName
            copies[index].updatedAt = Date()
            saveCurrent()
        }
    }

    func deleteSection(sectionID: String) {
        guard let index = currentCopyIndex else { return }
        copies[index].sections.removeAll { $0.id == sectionID }
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    func addQuestion(toSectionID sectionID: String, name: String? = nil, maxPoints: Double = 1) {
        guard let index = currentCopyIndex else { return }
        if let sectionIndex = copies[index].sections.firstIndex(where: { $0.id == sectionID }) {
            let questionNumber = copies[index].sections[sectionIndex].questions.count + 1
            let questionName = name ?? "Q\(questionNumber)"
            let newQuestion = Question(
                name: questionName,
                shortName: "Q\(questionNumber)",
                maxPoints: maxPoints
            )
            copies[index].sections[sectionIndex].questions.append(newQuestion)
            copies[index].updatedAt = Date()
            saveCurrent()
        }
    }

    func updateQuestion(questionID: String, name: String, shortName: String, maxPoints: Double) {
        guard let index = currentCopyIndex,
              let loc = findQuestionLocation(questionID: questionID, in: index) else { return }
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].name = name
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].shortName = shortName
        copies[index].sections[loc.sectionIndex].questions[loc.questionIndex].maxPoints = maxPoints
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    func deleteQuestion(questionID: String) {
        guard let index = currentCopyIndex else { return }
        for sectionIndex in copies[index].sections.indices {
            copies[index].sections[sectionIndex].questions.removeAll { $0.id == questionID }
        }
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    // MARK: - Stamps

    // MARK: - Annotations (stamps and texts)

    func addStamp(_ stamp: StampDefinition, at position: RelativePosition) {
        guard let index = currentCopyIndex else { return }
        let annotation = Annotation(
            position: position,
            content: .stamp(definitionID: stamp.id, text: stamp.text, color: stamp.color)
        )
        copies[index].annotations.append(annotation)
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    func addTextAnnotation(_ text: String, at position: RelativePosition) {
        guard let index = currentCopyIndex else { return }
        let annotation = Annotation(position: position, content: .text(text))
        copies[index].annotations.append(annotation)
        copies[index].updatedAt = Date()
        saveCurrent()
    }

    func updateTextAnnotation(id: String, text: String) {
        guard let index = currentCopyIndex else { return }
        if let annotationIndex = copies[index].annotations.firstIndex(where: { $0.id == id }) {
            copies[index].annotations[annotationIndex].content = .text(text)
            copies[index].updatedAt = Date()
            saveCurrent()
        }
    }

    func moveAnnotation(id: String, to position: RelativePosition) {
        guard let index = currentCopyIndex else { return }
        if let annotationIndex = copies[index].annotations.firstIndex(where: { $0.id == id }) {
            copies[index].annotations[annotationIndex].position = position
            copies[index].updatedAt = Date()
            saveCurrent()
        }
    }

    func removeAnnotation(id: String) {
        guard let index = currentCopyIndex else { return }
        copies[index].annotations.removeAll { $0.id == id }
        copies[index].updatedAt = Date()
        saveCurrent()
    }


    // MARK: - Global Stamp Management

    func addStampDefinition(text: String, color: StampColor, coefficient: Double) {
        let stamp = StampDefinition(text: text, color: color, coefficient: coefficient)
        stampDefinitions.append(stamp)
    }

    func removeStampDefinition(id: String) {
        // Don't delete default stamps
        guard !id.hasPrefix("default-") else { return }
        stampDefinitions.removeAll { $0.id == id }
    }

    // MARK: - Positioning

    func positionElement(_ element: PositionableElement, at position: RelativePosition) {
        switch element {
        case .total:
            setTotalPosition(position)
        case .section(let id):
            setSectionPosition(sectionID: id, position: position)
        case .question(let id):
            setQuestionPosition(questionID: id, position: position)
        }
        positioningElement = nil
    }

    func togglePositioning(for element: PositionableElement) {
        positioningElement = positioningElement == element ? nil : element
    }

    func clearPosition(for element: PositionableElement) {
        switch element {
        case .total:
            setTotalPosition(nil)
        case .section(let id):
            setSectionPosition(sectionID: id, position: nil)
        case .question(let id):
            setQuestionPosition(questionID: id, position: nil)
        }
    }

    // MARK: - Copy Management

    func addCopy(_ copy: CopyFeedback) {
        copies.append(copy)
    }

    func addCopies(_ newCopies: [CopyFeedback]) {
        copies.append(contentsOf: newCopies)
    }

    func deleteCopy(at offsets: IndexSet) {
        copies.remove(atOffsets: offsets)
    }

    func selectCopy(_ copy: CopyFeedback?) {
        selectedCopyID = copy?.id
    }

    // MARK: - Duplicate Rubric to Other Copies

    func applyCurrentBaremeToAll() {
        guard let currentIndex = currentCopyIndex else { return }
        let currentCopy = copies[currentIndex]

        for i in copies.indices where i != currentIndex {
            if copies[i].sections.isEmpty {
                // Copy structure with positions, without grades
                copies[i].sections = currentCopy.sections.map { section in
                    Section(
                        name: section.name,
                        shortName: section.shortName,
                        position: section.position,
                        questions: section.questions.map { q in
                            Question(
                                name: q.name,
                                shortName: q.shortName,
                                maxPoints: q.maxPoints,
                                position: q.position
                            )
                        }
                    )
                }
                // Copy total position
                copies[i].totalPosition = currentCopy.totalPosition
                copies[i].updatedAt = Date()
                try? copies[i].save()
            }
        }
    }

    // MARK: - Persistence

    func saveCurrent() {
        guard let index = currentCopyIndex else { return }
        do {
            try copies[index].save()
            saveError = nil
        } catch {
            saveError = error
        }
    }

    func saveAll() {
        var lastError: Error?
        for i in copies.indices {
            do {
                try copies[i].save()
            } catch {
                lastError = error
            }
        }
        saveError = lastError
    }
}

// MARK: - Sidebar Tab

enum SidebarTab: String, CaseIterable {
    case evaluation = "Grading"
    case bareme = "Rubric"

    var icon: String {
        switch self {
        case .evaluation: return "pencil.and.list.clipboard"
        case .bareme: return "list.bullet.rectangle"
        }
    }
}

// MARK: - Positionable Element

enum PositionableElement: Equatable, Hashable {
    case total
    case section(id: String)
    case question(id: String)
}

// MARK: - Tool

enum Tool: String, CaseIterable {
    case select     // Selection
    case text       // Free text
    case stamp      // Stamp

    var icon: String {
        switch self {
        case .select: return "cursorarrow"
        case .text: return "text.bubble"
        case .stamp: return "seal"
        }
    }

    var label: String {
        switch self {
        case .select: return "Select"
        case .text: return "Text"
        case .stamp: return "Stamp"
        }
    }
}
