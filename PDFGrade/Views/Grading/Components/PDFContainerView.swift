//
//  PDFContainerView.swift
//  PDFGrade
//
//  Container view for PDF display with floating toolbar overlay
//

import SwiftUI
import PDFKit

/// Container view that combines PDF display with floating toolbar
struct PDFContainerView: View {
    @Environment(GradingEngine.self) private var engine

    @Binding var currentPage: Int
    @Binding var scale: CGFloat
    let pageCount: Int
    let onPageCountChange: (Int) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            pdfContent
            floatingToolbar
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - PDF Content

    @ViewBuilder
    private var pdfContent: some View {
        if let copy = engine.currentCopy {
            PDFAnnotatedView(
                url: copy.pdfURL,
                currentPage: $currentPage,
                scale: $scale
            )
            .onAppear {
                loadPageCount(for: copy.pdfURL)
            }
            .onChange(of: engine.selectedCopyID) { _, _ in
                handleCopyChange()
            }
        }
    }

    // MARK: - Floating Toolbar

    private var floatingToolbar: some View {
        FloatingToolbar(
            scale: $scale,
            currentPage: $currentPage,
            pageCount: pageCount
        )
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - Helpers

    private func loadPageCount(for url: URL) {
        if let doc = PDFDocument(url: url) {
            onPageCountChange(doc.pageCount)
        }
    }

    private func handleCopyChange() {
        if let copy = engine.currentCopy {
            loadPageCount(for: copy.pdfURL)
            currentPage = 0
        }
    }
}
