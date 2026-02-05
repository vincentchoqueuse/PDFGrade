//
//  SplitPDFView.swift
//  PDFGrade
//
//  View for splitting a PDF into individual copies
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct SplitPDFView: View {
    @Environment(\.dismiss) private var dismiss
    let engine: GradingEngine

    @State private var sourceURL: URL?
    @State private var pagesPerCopy = 1
    @State private var baseName = "copy"
    @State private var pageCount = 0
    @State private var isProcessing = false
    @State private var showSourcePicker = false
    @State private var error: String?

    private var copyCount: Int {
        guard pageCount > 0 else { return 0 }
        return (pageCount + pagesPerCopy - 1) / pagesPerCopy
    }

    var body: some View {
        NavigationStack {
            Form {
                // Source PDF
                SwiftUI.Section("Source PDF") {
                    if let url = sourceURL {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent)
                                    .font(.headline)
                                Text("\(pageCount) pages")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Change") {
                                showSourcePicker = true
                            }
                        }
                    } else {
                        Button {
                            showSourcePicker = true
                        } label: {
                            Label("Select a PDF", systemImage: "doc.badge.plus")
                        }
                    }
                }

                // Configuration
                if sourceURL != nil {
                    SwiftUI.Section("Configuration") {
                        Stepper("Pages per copy: \(pagesPerCopy)", value: $pagesPerCopy, in: 1...max(1, pageCount))

                        TextField("Base name", text: $baseName)
                            .textInputAutocapitalization(.never)

                        HStack {
                            Text("Copies to create")
                            Spacer()
                            Text("\(copyCount)")
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                    }

                    // Preview
                    SwiftUI.Section("Preview") {
                        ForEach(0..<min(copyCount, 5), id: \.self) { i in
                            let startPage = i * pagesPerCopy + 1
                            let endPage = min((i + 1) * pagesPerCopy, pageCount)
                            HStack {
                                Text("\(baseName)_\(String(format: "%03d", i + 1)).pdf")
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text("p. \(startPage)-\(endPage)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if copyCount > 5 {
                            Text("... and \(copyCount - 5) more")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Error
                if let error = error {
                    SwiftUI.Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Split PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Split") {
                        splitPDF()
                    }
                    .disabled(sourceURL == nil || isProcessing)
                }
            }
            .sheet(isPresented: $showSourcePicker) {
                SourcePDFPicker(selectedURL: $sourceURL, pageCount: $pageCount)
            }
            .overlay {
                if isProcessing {
                    ProgressView("Splitting...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func splitPDF() {
        guard let sourceURL = sourceURL else { return }

        isProcessing = true
        error = nil

        Task {
            do {
                let results = try await performSplit(source: sourceURL)
                await MainActor.run {
                    engine.addCopies(results)
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func performSplit(source: URL) async throws -> [CopyFeedback] {
        // Start security-scoped access for external files
        let hasAccess = source.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                source.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: source) else {
            throw SplitError.invalidPDF
        }

        // Always output to app's Documents/PDFs folder for persistent access
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputDir = documentsDir.appendingPathComponent("PDFs", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var results: [CopyFeedback] = []

        for i in 0..<copyCount {
            let startPage = i * pagesPerCopy
            let endPage = min(startPage + pagesPerCopy, document.pageCount)

            let newDoc = PDFDocument()
            for pageIndex in startPage..<endPage {
                if let page = document.page(at: pageIndex) {
                    newDoc.insert(page, at: newDoc.pageCount)
                }
            }

            let fileName = "\(baseName)_\(String(format: "%03d", i + 1)).pdf"
            let pdfURL = outputDir.appendingPathComponent(fileName)

            guard newDoc.write(to: pdfURL) else {
                throw SplitError.saveFailed
            }

            let feedback = CopyFeedback(
                pdfPath: pdfURL.path,
                studentName: "Copy \(i + 1)"
            )

            try feedback.save()
            results.append(feedback)
        }

        return results
    }
}

// MARK: - Source PDF Picker

struct SourcePDFPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Binding var pageCount: Int
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: SourcePDFPicker

        init(_ parent: SourcePDFPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            parent.selectedURL = url

            if let doc = PDFDocument(url: url) {
                parent.pageCount = doc.pageCount
            }

            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

enum SplitError: LocalizedError {
    case invalidPDF
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidPDF: return "Invalid or corrupted PDF"
        case .saveFailed: return "Unable to save PDF"
        }
    }
}
