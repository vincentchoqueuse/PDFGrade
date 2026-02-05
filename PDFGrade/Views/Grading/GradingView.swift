//
//  GradingView.swift
//  PDFGrade
//
//  Main grading view - displays PDF with annotation tools and sidebar
//

import SwiftUI

/// Primary view for grading student submissions
///
/// This view combines:
/// - PDF display with annotation overlay
/// - Floating toolbar for quick access to tools
/// - Sidebar with evaluation and rubric tabs
///
/// The view uses `GradingViewModel` for navigation state and export operations,
/// while `GradingEngine` manages the domain logic.
struct GradingView: View {
    @Environment(GradingEngine.self) private var engine
    @State private var viewModel = GradingViewModel()

    var body: some View {
        mainContent
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .overlay { exportingOverlay }
            .alert("Export Error", isPresented: errorBinding) {
                Button("OK") { viewModel.clearExportError() }
            } message: {
                Text(viewModel.exportError ?? "")
            }
            .alert("Export Successful", isPresented: $viewModel.showExportSuccess) {
                Button("Share") { viewModel.showShareSheet = true }
                Button("OK", role: .cancel) {}
            } message: {
                if let url = viewModel.exportedURL {
                    Text("Saved to:\n\(url.lastPathComponent)")
                }
            }
            .alert("Export Rubric", isPresented: $viewModel.showExportRubricAlert) {
                TextField("Rubric name", text: $viewModel.rubricExportName)
                Button("Cancel", role: .cancel) { }
                Button("Export") { exportRubric() }
            } message: {
                Text("Enter a name for this rubric template")
            }
            .alert("Import Error", isPresented: rubricErrorBinding) {
                Button("OK") { viewModel.clearRubricImportError() }
            } message: {
                Text(viewModel.rubricImportError ?? "")
            }
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let url = viewModel.exportedURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $viewModel.showImportRubricPicker) {
                RubricImportPicker(engine: engine, errorMessage: $viewModel.rubricImportError)
            }
            .sheet(isPresented: $viewModel.showRubricShareSheet) {
                if let url = viewModel.rubricExportedURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $viewModel.showStampPicker) {
                NewStampSheet(engine: engine)
            }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        if let name = engine.currentCopy?.studentName, !name.isEmpty {
            return name
        }
        return "Scoresheet"
    }

    // MARK: - Main Content

    private var mainContent: some View {
        HStack(spacing: 0) {
            PDFContainerView(
                currentPage: $viewModel.currentPage,
                scale: $viewModel.scale,
                pageCount: viewModel.pageCount,
                onPageCountChange: { viewModel.pageCount = $0 }
            )

            if viewModel.showPanel {
                Divider()
                SidebarView()
                    .frame(width: ComponentSize.sidebarWidth)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: Spacing.md) {
                actionsMenu
                sidebarToggle
            }
        }
    }

    private var actionsMenu: some View {
        Menu {
            stampsMenu
            Divider()
            rubricMenuItems
            Divider()
            exportButton
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var stampsMenu: some View {
        Menu {
            ForEach(engine.stampDefinitions) { stamp in
                Button {
                    engine.selectedTool = .stamp
                    engine.selectedStamp = stamp
                    engine.selectedAnnotationID = nil
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: stamp.color.hex))
                            .frame(width: 12, height: 12)
                        Text(stamp.text)
                    }
                }
            }
            Divider()
            Button {
                viewModel.showStampPicker = true
            } label: {
                Label("New stamp...", systemImage: "plus")
            }
        } label: {
            Label("Stamps", systemImage: "seal")
        }
    }

    @ViewBuilder
    private var rubricMenuItems: some View {
        if let copy = engine.currentCopy, !copy.sections.isEmpty {
            Button {
                viewModel.beginRubricExport()
            } label: {
                Label("Export rubric", systemImage: "square.and.arrow.up")
            }
        }

        Button {
            viewModel.showImportRubricPicker = true
        } label: {
            Label("Import rubric", systemImage: "square.and.arrow.down")
        }

        if engine.copies.count > 1 {
            Button {
                engine.applyCurrentBaremeToAll()
            } label: {
                Label("Apply rubric to all copies", systemImage: "doc.on.doc")
            }
        }
    }

    private var exportButton: some View {
        Button {
            exportPDF()
        } label: {
            Label("Export PDF", systemImage: "square.and.arrow.up")
        }
    }

    private var sidebarToggle: some View {
        Button {
            viewModel.showPanel.toggle()
        } label: {
            Image(systemName: viewModel.showPanel ? "sidebar.right" : "sidebar.left")
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private var exportingOverlay: some View {
        if viewModel.isExporting {
            ProgressView("Exporting...")
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        }
    }

    // MARK: - Bindings

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.hasExportError },
            set: { if !$0 { viewModel.clearExportError() } }
        )
    }

    private var rubricErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.hasRubricImportError },
            set: { if !$0 { viewModel.clearRubricImportError() } }
        )
    }

    // MARK: - Actions

    private func exportPDF() {
        guard let copy = engine.currentCopy else { return }
        Task {
            await viewModel.exportPDF(copy: copy)
        }
    }

    private func exportRubric() {
        guard let copy = engine.currentCopy else { return }
        viewModel.exportRubric(from: copy)
    }
}
