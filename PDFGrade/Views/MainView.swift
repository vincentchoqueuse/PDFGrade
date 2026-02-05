//
//  MainView.swift
//  PDFGrade
//
//  Main view with NavigationSplitView
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sort Option

enum SortOption: String, CaseIterable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case scoreDesc = "Score (High to Low)"
    case scoreAsc = "Score (Low to High)"
    case statusCompleted = "Completed First"
    case statusIncomplete = "Incomplete First"

    var icon: String {
        switch self {
        case .nameAsc, .nameDesc: return "textformat.abc"
        case .scoreDesc, .scoreAsc: return "number"
        case .statusCompleted, .statusIncomplete: return "checkmark.circle"
        }
    }
}

struct MainView: View {
    @Environment(GradingEngine.self) private var engine

    @State private var showImportPicker = false
    @State private var showSplitPDF = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportedURL: URL?
    @State private var showExportSuccess = false
    @State private var showShareSheet = false
    @State private var exportMessage = ""
    @State private var sortOption: SortOption = .nameAsc

    private var sortedCopies: [CopyFeedback] {
        switch sortOption {
        case .nameAsc:
            return engine.copies.sorted { ($0.studentName ?? "").localizedCaseInsensitiveCompare($1.studentName ?? "") == .orderedAscending }
        case .nameDesc:
            return engine.copies.sorted { ($0.studentName ?? "").localizedCaseInsensitiveCompare($1.studentName ?? "") == .orderedDescending }
        case .scoreDesc:
            return engine.copies.sorted { $0.total > $1.total }
        case .scoreAsc:
            return engine.copies.sorted { $0.total < $1.total }
        case .statusCompleted:
            return engine.copies.sorted { ($0.isFullyGraded ? 0 : 1) < ($1.isFullyGraded ? 0 : 1) }
        case .statusIncomplete:
            return engine.copies.sorted { ($0.isFullyGraded ? 1 : 0) < ($1.isFullyGraded ? 1 : 0) }
        }
    }

    var body: some View {
        @Bindable var engine = engine

        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .sheet(isPresented: $showImportPicker) {
            DocumentPicker(engine: engine)
        }
        .sheet(isPresented: $showSplitPDF) {
            SplitPDFView(engine: engine)
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        Group {
            if engine.copies.isEmpty {
                emptyState
            } else {
                copyList
            }
        }
        .navigationTitle("Scoresheets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    // Sort menu
                    if !engine.copies.isEmpty {
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button {
                                    sortOption = option
                                } label: {
                                    HStack {
                                        Text(option.rawValue)
                                        if sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }

                    // Add menu
                    Menu {
                        Button {
                            showImportPicker = true
                        } label: {
                            Label("Import PDFs", systemImage: "doc.badge.plus")
                        }

                        Button {
                            showSplitPDF = true
                        } label: {
                            Label("Split PDF", systemImage: "scissors")
                        }

                        if !engine.copies.isEmpty {
                            Divider()

                            Button {
                                engine.saveAll()
                            } label: {
                                Label("Save all", systemImage: "square.and.arrow.down")
                            }

                            Divider()

                            Menu {
                                Button {
                                    exportAllPDFsAsZip()
                                } label: {
                                    Label("Export All PDFs (ZIP)", systemImage: "doc.zipper")
                                }

                                Divider()

                                Button {
                                    exportAllAsJSON()
                                } label: {
                                    Label("Export JSON", systemImage: "doc.text")
                                }

                                Button {
                                    exportAllAsCSV()
                                } label: {
                                    Label("Export CSV", systemImage: "tablecells")
                                }
                            } label: {
                                Label("Export Grades", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No scoresheets")
                .font(.title2)

            Text("Import or split your PDFs\nthen create a rubric for grading")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    showSplitPDF = true
                } label: {
                    Label("Split PDF", systemImage: "scissors")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showImportPicker = true
                } label: {
                    Label("Import PDFs", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: 250)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    @ViewBuilder
    private var copyList: some View {
        List(selection: Bindable(engine).selectedCopyID) {
            SwiftUI.Section {
                ForEach(sortedCopies) { copy in
                    NavigationLink(value: copy.id) {
                        CopyRow(copy: copy)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if let index = engine.copies.firstIndex(where: { $0.id == copy.id }) {
                                engine.deleteCopy(at: IndexSet(integer: index))
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            exportCopy(copy)
                        } label: {
                            Label("Export PDF", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive) {
                            if let index = engine.copies.firstIndex(where: { $0.id == copy.id }) {
                                engine.deleteCopy(at: IndexSet(integer: index))
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("\(engine.copies.count) scoresheets")
                    Spacer()
                    let graded = engine.copies.filter(\.isFullyGraded).count
                    Text("\(graded) graded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if isExporting {
                ProgressView("Exporting...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("Export Error", isPresented: .init(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("Share") {
                showShareSheet = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportCopy(_ copy: CopyFeedback) {
        isExporting = true

        Task {
            do {
                let url = try await PDFExporter.export(copy: copy)
                await MainActor.run {
                    isExporting = false
                    exportedURL = url
                    exportMessage = "Saved to:\n\(url.lastPathComponent)"
                    showExportSuccess = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }

    private func exportAllAsJSON() {
        isExporting = true

        Task {
            do {
                let url = try await GradesExporter.exportJSON(copies: engine.copies)
                await MainActor.run {
                    isExporting = false
                    exportedURL = url
                    exportMessage = "Exported \(engine.copies.count) scoresheets to:\n\(url.lastPathComponent)"
                    showExportSuccess = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }

    private func exportAllAsCSV() {
        isExporting = true

        Task {
            do {
                let url = try await GradesExporter.exportCSV(copies: engine.copies)
                await MainActor.run {
                    isExporting = false
                    exportedURL = url
                    exportMessage = "Exported \(engine.copies.count) scoresheets to:\n\(url.lastPathComponent)"
                    showExportSuccess = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }

    private func exportAllPDFsAsZip() {
        isExporting = true

        Task {
            do {
                let url = try await GradesExporter.exportAllPDFsAsZip(copies: engine.copies)
                await MainActor.run {
                    isExporting = false
                    exportedURL = url
                    exportMessage = "Exported \(engine.copies.count) PDFs to:\n\(url.lastPathComponent)"
                    showExportSuccess = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if engine.currentCopy != nil {
            GradingView()
        } else {
            ContentUnavailableView(
                "Select a scoresheet",
                systemImage: "doc.text.magnifyingglass"
            )
        }
    }
}

// MARK: - Copy Row

struct CopyRow: View {
    let copy: CopyFeedback

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Image(systemName: copy.isFullyGraded ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 10))
                .foregroundStyle(copy.isFullyGraded ? .green : .secondary)

            // Name
            Text(copy.studentName ?? "Scoresheet \(copy.id.prefix(4))")
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            // Score
            Text("\(NumberFormatter.format(copy.total))/\(NumberFormatter.format(copy.maxTotal))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(copy.isFullyGraded ? .primary : .secondary)
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let engine: GradingEngine
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                // Start security-scoped access
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                // Copy to app's Documents folder for persistent access
                guard let localURL = copyToDocuments(url) else {
                    print("Failed to copy PDF: \(url.lastPathComponent)")
                    continue
                }

                let copy = CopyFeedback(
                    pdfPath: localURL.path,
                    studentName: url.deletingPathExtension().lastPathComponent
                )
                parent.engine.addCopy(copy)
            }
            parent.dismiss()
        }

        private func copyToDocuments(_ sourceURL: URL) -> URL? {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let pdfsDir = documentsDir.appendingPathComponent("PDFs", isDirectory: true)

            // Create PDFs directory if needed
            try? FileManager.default.createDirectory(at: pdfsDir, withIntermediateDirectories: true)

            // Generate unique filename if needed
            var destURL = pdfsDir.appendingPathComponent(sourceURL.lastPathComponent)
            var counter = 1
            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension

            while FileManager.default.fileExists(atPath: destURL.path) {
                destURL = pdfsDir.appendingPathComponent("\(baseName)_\(counter).\(ext)")
                counter += 1
            }

            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                return destURL
            } catch {
                print("Error copying PDF: \(error)")
                return nil
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
