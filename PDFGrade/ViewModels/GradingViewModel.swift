//
//  GradingViewModel.swift
//  PDFGrade
//
//  ViewModel for GradingView - handles navigation state)  and export operations
//

import SwiftUI
import PDFKit

/// ViewModel managing the grading view state and export operations
@Observable
@MainActor
final class GradingViewModel {

    // MARK: - PDF Navigation State

    /// Current page index (0-based)
    var currentPage: Int = 0

    /// Total number of pages in the current PDF
    var pageCount: Int = 1

    /// Current zoom scale (1.0 = 100%)
    var scale: CGFloat = 1.0

    /// Whether the sidebar panel is visible
    var showPanel: Bool = true

    // MARK: - Export State

    /// Indicates an export operation is in progress
    private(set) var isExporting: Bool = false

    /// Error message from failed export, nil if no error
    var exportError: String?

    /// URL of successfully exported PDF
    var exportedURL: URL?

    /// Controls visibility of export success alert
    var showExportSuccess: Bool = false

    /// Controls visibility of share sheet
    var showShareSheet: Bool = false

    // MARK: - Rubric Export/Import State

    /// Controls visibility of rubric export alert
    var showExportRubricAlert: Bool = false

    /// Controls visibility of rubric import picker
    var showImportRubricPicker: Bool = false

    /// Name for rubric export
    var rubricExportName: String = ""

    /// URL of exported rubric file
    var rubricExportedURL: URL?

    /// Controls visibility of rubric share sheet
    var showRubricShareSheet: Bool = false

    /// Error message from rubric import
    var rubricImportError: String?

    // MARK: - Stamp State

    /// Controls visibility of new stamp sheet
    var showStampPicker: Bool = false

    // MARK: - Computed Properties

    /// Whether an export error is present
    var hasExportError: Bool {
        exportError != nil
    }

    /// Whether a rubric import error is present
    var hasRubricImportError: Bool {
        rubricImportError != nil
    }

    // MARK: - PDF Operations

    /// Loads the page count for a given PDF URL
    /// - Parameter url: URL of the PDF file
    func loadPageCount(for url: URL) {
        if let document = PDFDocument(url: url) {
            pageCount = document.pageCount
        }
    }

    /// Resets navigation to first page when changing copies
    func resetNavigation() {
        currentPage = 0
    }

    /// Adjusts zoom level by the specified delta
    /// - Parameter delta: Amount to change zoom (positive = zoom in)
    func adjustZoom(by delta: CGFloat) {
        scale = max(0.5, min(3.0, scale + delta))
    }

    /// Navigates to the previous page if possible
    func previousPage() {
        currentPage = max(0, currentPage - 1)
    }

    /// Navigates to the next page if possible
    func nextPage() {
        currentPage = min(pageCount - 1, currentPage + 1)
    }

    // MARK: - Export Operations

    /// Exports the current copy as a graded PDF
    /// - Parameter copy: The copy feedback to export
    func exportPDF(copy: CopyFeedback) async {
        isExporting = true

        do {
            let url = try await PDFExporter.export(copy: copy)
            exportedURL = url
            showExportSuccess = true
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }

    /// Exports the rubric from the current copy
    /// - Parameter copy: The copy containing the rubric
    func exportRubric(from copy: CopyFeedback) {
        do {
            let url = try GradesExporter.exportRubric(from: copy, name: rubricExportName)
            rubricExportedURL = url
            showRubricShareSheet = true
        } catch {
            rubricImportError = error.localizedDescription
        }
    }

    /// Clears the export error
    func clearExportError() {
        exportError = nil
    }

    /// Clears the rubric import error
    func clearRubricImportError() {
        rubricImportError = nil
    }

    /// Initiates rubric export flow
    func beginRubricExport() {
        rubricExportName = "My Rubric"
        showExportRubricAlert = true
    }
}
