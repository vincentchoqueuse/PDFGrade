//
//  RubricImportPicker.swift
//  PDFGrade
//
//  Document picker for importing rubric templates
//

import SwiftUI
import UniformTypeIdentifiers

/// UIKit document picker wrapped for SwiftUI rubric import
struct RubricImportPicker: UIViewControllerRepresentable {
    let engine: GradingEngine
    @Binding var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: RubricImportPicker

        init(_ parent: RubricImportPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            importRubric(from: url)
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }

        private func importRubric(from url: URL) {
            do {
                let sections = try GradesExporter.importRubric(from: url)

                if let index = parent.engine.currentCopyIndex {
                    parent.engine.copies[index].sections = sections
                    parent.engine.copies[index].updatedAt = Date()
                    parent.engine.saveCurrent()
                }
            } catch {
                parent.errorMessage = "Failed to import: \(error.localizedDescription)"
            }
        }
    }
}
