//
//  EvaluationComponents.swift
//  PDFGrade
//
//  Reusable components for the evaluation tab
//

import SwiftUI

// MARK: - Student Name Field

/// Text field for entering the student's name
struct StudentNameField: View {
    @Environment(GradingEngine.self) private var engine
    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: "person")
                .foregroundStyle(.secondary)
            TextField("Student name", text: $name)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onAppear { loadName() }
                .onChange(of: engine.selectedCopyID) { _, _ in loadName() }
                .onChange(of: isFocused) { _, focused in
                    if !focused { engine.setStudentName(name) }
                }
                .onSubmit { engine.setStudentName(name) }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private func loadName() {
        name = engine.currentCopy?.studentName ?? ""
    }
}

// MARK: - Total Score Card

/// Card displaying the total score with position button
struct TotalScoreCard: View {
    @Environment(GradingEngine.self) private var engine
    let copy: CopyFeedback

    var body: some View {
        HStack {
            scoreDisplay
            Spacer()
            PositionButton(element: .total, isPositioned: copy.totalPosition != nil)
        }
        .cardStyle()
    }

    private var scoreDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(NumberFormatter.format(copy.total))
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("/\(NumberFormatter.format(copy.maxTotal))")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Section Evaluation Card

/// Card displaying a section with its questions for grading
struct SectionEvaluationCard: View {
    @Environment(GradingEngine.self) private var engine
    let section: Section

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            Divider()
            questionsList
        }
        .cardStyle()
    }

    private var header: some View {
        HStack {
            Text(section.name)
                .font(.subheadline.bold())
            Spacer()
            Text("\(NumberFormatter.format(section.subtotal))/\(NumberFormatter.format(section.maxSubtotal))")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(.accentColor)
        }
    }

    private var questionsList: some View {
        ForEach(section.questions) { question in
            QuestionEvaluationRow(question: question)
        }
    }
}

// MARK: - Question Evaluation Row

/// Row for grading a single question
struct QuestionEvaluationRow: View {
    @Environment(GradingEngine.self) private var engine
    let question: Question

    @State private var pointsText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: Spacing.sm) {
            headerRow
            controlsRow
        }
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Text(question.shortName)
                .font(.subheadline.bold())
            Spacer()
            stampMenu
        }
    }

    private var stampMenu: some View {
        Menu {
            ForEach(engine.stampDefinitions) { stamp in
                Button {
                    engine.setQuestionStamp(questionID: question.id, stamp: stamp)
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: stamp.color.hex))
                            .frame(width: 10, height: 10)
                        Text("\(stamp.text) (\(Int(stamp.coefficient * 100))%)")
                    }
                }
            }

            if question.hasStamp {
                Divider()
                Button(role: .destructive) {
                    engine.clearQuestionStamp(questionID: question.id)
                } label: {
                    Label("Remove stamp", systemImage: "xmark")
                }
            }
        } label: {
            stampMenuLabel
        }
    }

    private var stampMenuLabel: some View {
        HStack(spacing: Spacing.xs) {
            if let stampText = question.stampText {
                Text(stampText)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: "seal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .pillStyle()
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        HStack {
            StatusSelector(currentStatus: question.status) { status in
                engine.setQuestionStatus(questionID: question.id, status: status)
            }
            Spacer()
            pointsControl
        }
    }

    private var pointsControl: some View {
        HStack(spacing: Spacing.xs) {
            decrementButton
            pointsTextField
            maxPointsLabel
            incrementButton
        }
    }

    private var decrementButton: some View {
        Button {
            let newPoints = max(0, (question.points ?? 0) - 0.5)
            engine.setPoints(questionID: question.id, points: newPoints)
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
            let newPoints = min(question.maxPoints, (question.points ?? 0) + 0.5)
            engine.setPoints(questionID: question.id, points: newPoints)
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
            .font(.subheadline.bold().monospacedDigit())
            .multilineTextAlignment(.center)
            .frame(width: 40)
            .keyboardType(.decimalPad)
            .focused($isFocused)
            .onAppear { updateText() }
            .onChange(of: question.points) { _, _ in updateText() }
            .onSubmit { commitPoints() }
            .onChange(of: isFocused) { _, focused in
                if !focused { commitPoints() }
            }
    }

    private var maxPointsLabel: some View {
        Text("/\(NumberFormatter.format(question.maxPoints))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private func updateText() {
        pointsText = question.points.map { NumberFormatter.format($0) } ?? ""
    }

    private func commitPoints() {
        if let value = Double(pointsText.replacingOccurrences(of: ",", with: ".")) {
            let clamped = min(max(0, value), question.maxPoints)
            engine.setPoints(questionID: question.id, points: clamped)
        }
        updateText()
    }
}

// MARK: - Status Selector

/// Segmented control for selecting question status
struct StatusSelector: View {
    @Environment(\.colorScheme) private var colorScheme
    let currentStatus: QuestionStatus
    let onSelect: (QuestionStatus) -> Void

    var body: some View {
        HStack(spacing: Spacing.sm - 2) {
            ForEach(QuestionStatus.allCases, id: \.self) { status in
                statusButton(for: status)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm - 2)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private func statusButton(for status: QuestionStatus) -> some View {
        Button { onSelect(status) } label: {
            Circle()
                .fill(Color(hex: status.color))
                .frame(width: ComponentSize.statusIndicator, height: ComponentSize.statusIndicator)
                .opacity(currentStatus == status ? 1 : (colorScheme == .dark ? 0.35 : 0.25))
                .scaleEffect(currentStatus == status ? 1.2 : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: AnimationDuration.fast), value: currentStatus)
    }
}
