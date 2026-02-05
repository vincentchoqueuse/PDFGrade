//
//  SidebarView.swift
//  PDFGrade
//
//  Sidebar containing evaluation and rubric tabs
//

import SwiftUI

/// Main sidebar view with tab navigation
struct SidebarView: View {
    @Environment(GradingEngine.self) private var engine

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            tabContent
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var tabPicker: some View {
        Picker("", selection: Bindable(engine).sidebarTab) {
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    @ViewBuilder
    private var tabContent: some View {
        switch engine.sidebarTab {
        case .evaluation:
            EvaluationTabView()
        case .bareme:
            RubricTabView()
        }
    }
}

// MARK: - Evaluation Tab

/// Tab displaying grading controls for the current copy
struct EvaluationTabView: View {
    @Environment(GradingEngine.self) private var engine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let copy = engine.currentCopy {
                    StudentNameField()
                    TotalScoreCard(copy: copy)

                    ForEach(copy.sections) { section in
                        SectionEvaluationCard(section: section)
                    }

                    if copy.sections.isEmpty {
                        emptyState
                    }
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No rubric")
                .font(.headline)
            Text("Go to the Rubric tab\nto create sections and questions")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Rubric Tab

/// Tab for editing the rubric structure
struct RubricTabView: View {
    @Environment(GradingEngine.self) private var engine

    var body: some View {
        List {
            if let copy = engine.currentCopy {
                totalSection(copy: copy)
                sectionsContent(copy: copy)
                addSectionButton
            }
        }
        .listStyle(.insetGrouped)
    }

    private func totalSection(copy: CopyFeedback) -> some View {
        SwiftUI.Section {
            HStack {
                Text("Total")
                Spacer()
                Text("\(NumberFormatter.format(copy.maxTotal)) pts")
                    .foregroundStyle(.secondary)
                PositionButton(element: .total, isPositioned: copy.totalPosition != nil)
            }
        }
    }

    private func sectionsContent(copy: CopyFeedback) -> some View {
        ForEach(copy.sections) { section in
            RubricSectionView(section: section)
        }
        .onDelete { offsets in
            for offset in offsets {
                let section = copy.sections[offset]
                engine.deleteSection(sectionID: section.id)
            }
        }
    }

    private var addSectionButton: some View {
        SwiftUI.Section {
            Button {
                engine.addSection()
            } label: {
                Label("Add section", systemImage: "plus")
            }
        }
    }
}
