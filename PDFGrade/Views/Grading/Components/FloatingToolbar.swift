//
//  FloatingToolbar.swift
//  PDFGrade
//
//  Draggable floating toolbar for PDF annotation tools
//

import SwiftUI

/// A floating, draggable toolbar providing quick access to annotation tools
struct FloatingToolbar: View {
    @Environment(GradingEngine.self) private var engine

    @Binding var scale: CGFloat
    @Binding var currentPage: Int
    let pageCount: Int

    @State private var position: CGPoint = .zero
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        toolbarContent
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .shadow(.medium)
            .offset(x: position.x + dragOffset.width, y: position.y + dragOffset.height)
            .gesture(dragGesture)
            .onTapGesture(count: 2) { resetPosition() }
    }

    // MARK: - Content

    @ViewBuilder
    private var toolbarContent: some View {
        HStack(spacing: Spacing.md) {
            dragHandle
            ToolbarDivider()

            toolButtons
            selectedStampIndicator
            selectedAnnotationActions

            ToolbarDivider()
            zoomControls

            if pageCount > 1 {
                ToolbarDivider()
                pageControls
            }
        }
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: IconSize.sm, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 30)
    }

    // MARK: - Tool Buttons

    private var toolButtons: some View {
        HStack(spacing: Spacing.sm) {
            ToolButton(tool: .select, selectedTool: engine.selectedTool) {
                engine.selectedTool = .select
                engine.selectedStamp = nil
            }

            ToolButton(tool: .text, selectedTool: engine.selectedTool) {
                engine.selectedTool = .text
                engine.selectedStamp = nil
                engine.selectedAnnotationID = nil
            }
        }
    }

    // MARK: - Selected Stamp Indicator

    @ViewBuilder
    private var selectedStampIndicator: some View {
        if engine.selectedTool == .stamp, let stamp = engine.selectedStamp {
            HStack(spacing: Spacing.sm) {
                ToolbarDivider()
                StampBadge(stamp: stamp)
                dismissStampButton
            }
        }
    }

    private var dismissStampButton: some View {
        Button {
            engine.selectedTool = .select
            engine.selectedStamp = nil
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selected Annotation Actions

    @ViewBuilder
    private var selectedAnnotationActions: some View {
        if let annotation = engine.selectedAnnotation {
            HStack(spacing: Spacing.sm) {
                ToolbarDivider()
                AnnotationActionBar(annotation: annotation)
            }
        }
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        HStack(spacing: Spacing.sm) {
            Button { scale = max(0.5, scale - 0.25) } label: {
                Image(systemName: "minus.magnifyingglass")
            }

            Text("\(Int(scale * 100))%")
                .font(.caption.monospacedDigit())
                .frame(width: 40)

            Button { scale = min(3, scale + 0.25) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page Controls

    private var pageControls: some View {
        HStack(spacing: Spacing.sm) {
            Button { currentPage = max(0, currentPage - 1) } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPage == 0)

            Text("\(currentPage + 1)/\(pageCount)")
                .font(.caption.monospacedDigit())
                .frame(minWidth: 40)

            Button { currentPage = min(pageCount - 1, currentPage + 1) } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(currentPage >= pageCount - 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                position.x += value.translation.width
                position.y += value.translation.height
            }
    }

    private func resetPosition() {
        withAnimation(.spring(duration: AnimationDuration.normal)) {
            position = .zero
        }
    }
}

// MARK: - Supporting Views

/// Vertical divider for toolbar sections
private struct ToolbarDivider: View {
    var body: some View {
        Divider().frame(height: 30)
    }
}

/// Badge showing currently selected stamp
private struct StampBadge: View {
    let stamp: StampDefinition

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(Color(hex: stamp.color.hex))
                .frame(width: ComponentSize.stampIndicator, height: ComponentSize.stampIndicator)
            Text(stamp.text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .pillStyle(background: Color.accentColor.opacity(0.15))
    }
}

/// Action bar for selected annotation
private struct AnnotationActionBar: View {
    @Environment(GradingEngine.self) private var engine
    let annotation: Annotation

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if annotation.content.isText {
                editButton
            }
            deleteButton
            deselectButton
        }
        .pillStyle(background: Color.blue.opacity(0.15))
    }

    private var editButton: some View {
        Button {
            engine.inlineEditingAnnotationID = annotation.id
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: IconSize.lg))
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button {
            engine.removeAnnotation(id: annotation.id)
            engine.selectedAnnotationID = nil
        } label: {
            Image(systemName: "trash")
                .font(.system(size: IconSize.lg))
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
    }

    private var deselectButton: some View {
        Button {
            engine.selectedAnnotationID = nil
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tool Button

/// Button for selecting annotation tools
struct ToolButton: View {
    let tool: Tool
    let selectedTool: Tool
    let action: () -> Void

    private var isSelected: Bool {
        selectedTool == tool
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.icon)
                .font(.system(size: IconSize.md))
                .frame(width: 40, height: 40)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .blue : .primary)
    }
}
