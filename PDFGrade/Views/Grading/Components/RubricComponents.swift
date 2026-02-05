//
//  RubricComponents.swift
//  PDFGrade
//
//  Reusable components for the rubric tab
//

import SwiftUI

// MARK: - Rubric Section View

/// Section view for editing rubric structure
struct RubricSectionView: View {
    @Environment(GradingEngine.self) private var engine
    let section: Section

    @State private var showRenameAlert = false
    @State private var newName: String = ""

    var body: some View {
        SwiftUI.Section {
            questionsList
            addQuestionButton
        } header: {
            sectionHeader
        }
        .alert("Rename Section", isPresented: $showRenameAlert) {
            TextField("Section name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Save") { saveNewName() }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Text(section.name)
            Spacer()
            Text("\(NumberFormatter.format(section.maxSubtotal)) pts")
                .font(.caption)
            PositionButton(element: .section(id: section.id), isPositioned: section.position != nil)
        }
        .contextMenu {
            Button {
                newName = section.name
                showRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button(role: .destructive) {
                engine.deleteSection(sectionID: section.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Questions

    private var questionsList: some View {
        ForEach(section.questions) { question in
            QuestionRubricRow(question: question, sectionID: section.id)
        }
        .onDelete { offsets in
            for offset in offsets {
                let question = section.questions[offset]
                engine.deleteQuestion(questionID: question.id)
            }
        }
    }

    private var addQuestionButton: some View {
        Button {
            engine.addQuestion(toSectionID: section.id)
        } label: {
            Label("Add question", systemImage: "plus")
                .font(.subheadline)
        }
    }

    private func saveNewName() {
        let shortName = String(newName.prefix(2)).uppercased()
        engine.updateSection(sectionID: section.id, name: newName, shortName: shortName)
    }
}

// MARK: - Question Rubric Row

/// Row for editing a question's max points in the rubric
struct QuestionRubricRow: View {
    @Environment(GradingEngine.self) private var engine
    let question: Question
    let sectionID: String

    @State private var pointsText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(question.shortName)
                .frame(width: 40, alignment: .leading)

            Spacer()

            pointsControls
            positionButton
        }
    }

    // MARK: - Points Controls

    private var pointsControls: some View {
        HStack(spacing: Spacing.xs) {
            decrementButton
            pointsTextField
            incrementButton
            Text("pts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var decrementButton: some View {
        Button {
            let newMax = max(0.5, question.maxPoints - 0.5)
            updateMaxPoints(newMax)
        } label: {
            Image(systemName: "minus")
                .font(.system(size: IconSize.xs, weight: .bold))
                .frame(width: ComponentSize.controlButton, height: ComponentSize.controlButton)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var incrementButton: some View {
        Button {
            let newMax = question.maxPoints + 0.5
            updateMaxPoints(newMax)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: IconSize.xs, weight: .bold))
                .frame(width: ComponentSize.controlButton, height: ComponentSize.controlButton)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var pointsTextField: some View {
        TextField("", text: $pointsText)
            .font(.body.monospacedDigit())
            .multilineTextAlignment(.center)
            .frame(width: 40)
            .keyboardType(.decimalPad)
            .focused($isFocused)
            .onAppear { loadPoints() }
            .onChange(of: question.maxPoints) { _, _ in loadPoints() }
            .onSubmit { commitPoints() }
            .onChange(of: isFocused) { _, focused in
                if !focused { commitPoints() }
            }
    }

    private var positionButton: some View {
        PositionButton(element: .question(id: question.id), isPositioned: question.position != nil)
    }

    // MARK: - Helpers

    private func loadPoints() {
        pointsText = NumberFormatter.format(question.maxPoints)
    }

    private func commitPoints() {
        if let value = Double(pointsText.replacingOccurrences(of: ",", with: ".")), value > 0 {
            updateMaxPoints(value)
        }
        loadPoints()
    }

    private func updateMaxPoints(_ value: Double) {
        engine.updateQuestion(
            questionID: question.id,
            name: question.name,
            shortName: question.shortName,
            maxPoints: value
        )
    }
}

// MARK: - Position Button

/// Button for positioning elements on the PDF
struct PositionButton: View {
    @Environment(GradingEngine.self) private var engine
    let element: PositionableElement
    let isPositioned: Bool

    private var isPositioning: Bool {
        engine.positioningElement == element
    }

    private var iconName: String {
        if isPositioning {
            return "scope"
        } else if isPositioned {
            return "mappin.circle.fill"
        } else {
            return "mappin.circle"
        }
    }

    var body: some View {
        Button {
            engine.togglePositioning(for: element)
        } label: {
            Image(systemName: iconName)
                .font(.body)
                .frame(width: 22, height: 22)
                .foregroundStyle(isPositioning ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isPositioned {
                Button {
                    engine.togglePositioning(for: element)
                } label: {
                    Label("Reposition", systemImage: "scope")
                }

                Button(role: .destructive) {
                    engine.clearPosition(for: element)
                } label: {
                    Label("Remove position", systemImage: "trash")
                }
            }
        }
    }
}
