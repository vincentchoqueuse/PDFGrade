//
//  PDFAnnotatedView.swift
//  PDFGrade
//
//  PDF view with reactive overlays via @Observable
//

import SwiftUI
import PDFKit

struct PDFAnnotatedView: UIViewRepresentable {
    @Environment(GradingEngine.self) private var engine

    let url: URL?
    @Binding var currentPage: Int
    @Binding var scale: CGFloat

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = false
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemGray6
        pdfView.pageOverlayViewProvider = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tap.numberOfTapsRequired = 1
        pdfView.addGestureRecognizer(tap)

        // Make PDFView's tap gestures require our tap to fail first
        // This prevents double-tap zoom from interfering
        for gestureRecognizer in pdfView.gestureRecognizers ?? [] {
            if let tapGR = gestureRecognizer as? UITapGestureRecognizer, tapGR != tap {
                tapGR.require(toFail: tap)
            }
        }

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pdfView.addGestureRecognizer(pan)

        context.coordinator.pdfView = pdfView
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Update engine reference
        context.coordinator.engine = engine

        // Load document if necessary
        if let url = url, pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
            // Cache the base scale factor to avoid recalculation jitter
            context.coordinator.baseScaleFactor = pdfView.scaleFactorForSizeToFit
            pdfView.scaleFactor = context.coordinator.baseScaleFactor * scale
            context.coordinator.lastScale = scale
            context.coordinator.clearCache()
            return // Early return after document load to avoid redundant updates
        }

        guard pdfView.document != nil else { return }

        // Update base scale factor if it's not set (e.g., after layout changes)
        if context.coordinator.baseScaleFactor == 0 {
            context.coordinator.baseScaleFactor = pdfView.scaleFactorForSizeToFit
        }

        // Page - only update if actually changed
        if let doc = pdfView.document,
           currentPage < doc.pageCount,
           let page = doc.page(at: currentPage),
           pdfView.currentPage != page {
            pdfView.go(to: page)
        }

        // Zoom - only update if scale binding actually changed
        if context.coordinator.lastScale != scale {
            context.coordinator.lastScale = scale
            let target = context.coordinator.baseScaleFactor * scale
            pdfView.scaleFactor = target
        }

        // Refresh overlay when tool changes
        if context.coordinator.lastTool != engine.selectedTool {
            context.coordinator.lastTool = engine.selectedTool
            context.coordinator.refreshOverlays()
        }

        // Refresh overlay when selection changes
        if context.coordinator.lastSelectedID != engine.selectedAnnotationID {
            context.coordinator.lastSelectedID = engine.selectedAnnotationID
            context.coordinator.refreshOverlays()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PDFPageOverlayViewProvider, UIGestureRecognizerDelegate {
        weak var engine: GradingEngine?
        private var cache: [Int: UIHostingController<AnyView>] = [:]
        weak var pdfView: PDFView?
        var lastTool: Tool = .select
        var lastSelectedID: String?
        var baseScaleFactor: CGFloat = 0
        var lastScale: CGFloat = 1.0
        private var dragStartPosition: RelativePosition?

        init(engine: GradingEngine) {
            self.engine = engine
        }

        func clearCache() {
            cache.removeAll()
        }

        func refreshOverlays() {
            // Force refresh all cached overlays
            guard let engine = engine,
                  let pdfView = pdfView,
                  let doc = pdfView.document else { return }

            for (pageIndex, host) in cache {
                guard let page = doc.page(at: pageIndex) else { continue }
                let pageSize = page.bounds(for: .mediaBox).size

                let overlayView = AnyView(
                    AnnotationPageView(pageIndex: pageIndex, pageSize: pageSize)
                        .environment(engine)
                )
                host.rootView = overlayView
            }
        }

        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            guard let engine = engine,
                  let doc = view.document else { return nil }

            let pageIndex = doc.index(for: page)
            let pageSize = page.bounds(for: .mediaBox).size
            let pageBounds = page.bounds(for: .mediaBox)

            // Create SwiftUI view with engine injection
            let overlayView = AnyView(
                AnnotationPageView(pageIndex: pageIndex, pageSize: pageSize)
                    .environment(engine)
            )

            let host: UIHostingController<AnyView>
            if let cached = cache[pageIndex] {
                cached.rootView = overlayView
                host = cached
            } else {
                host = UIHostingController(rootView: overlayView)
                host.view.backgroundColor = .clear
                host.view.isUserInteractionEnabled = true
                cache[pageIndex] = host
            }

            host.view.frame = pageBounds
            host.view.isUserInteractionEnabled = true
            return host.view
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let engine = engine,
                  gesture.state == .ended,
                  let pdfView = gesture.view as? PDFView,
                  let page = pdfView.currentPage,
                  let doc = pdfView.document else { return }

            let locationInPDF = pdfView.convert(gesture.location(in: pdfView), to: page)
            let bounds = page.bounds(for: .mediaBox)
            let x = locationInPDF.x / bounds.width
            let y = locationInPDF.y / bounds.height

            guard (0...1).contains(x), (0...1).contains(y) else { return }

            let pageIndex = doc.index(for: page)
            let position = RelativePosition(x: x, y: y, page: pageIndex)

            // If positioning an element
            if let element = engine.positioningElement {
                engine.positionElement(element, at: position)
                return
            }

            // Check if we tapped on an annotation (in select mode)
            if engine.selectedTool == .select {
                if let tappedAnnotation = findAnnotation(at: position, pageIndex: pageIndex, pageSize: bounds.size) {
                    // Toggle selection
                    if engine.selectedAnnotationID == tappedAnnotation.id {
                        engine.selectedAnnotationID = nil
                    } else {
                        engine.selectedAnnotationID = tappedAnnotation.id
                    }
                    refreshOverlays()
                    return
                } else {
                    // Tapped on empty space - clear selection
                    if engine.selectedAnnotationID != nil {
                        engine.selectedAnnotationID = nil
                        refreshOverlays()
                    }
                    return
                }
            }

            // Otherwise, use the selected tool
            switch engine.selectedTool {
            case .select:
                break // Already handled above
            case .text:
                // Finish any current inline editing first
                if engine.inlineEditingAnnotationID != nil {
                    engine.finishInlineEditing()
                }
                // Create new annotation and start inline editing
                engine.createAndEditTextAnnotation(at: position)
                refreshOverlays()
            case .stamp:
                if let stamp = engine.selectedStamp {
                    engine.addStamp(stamp, at: position)
                }
            }
        }

        private func findAnnotation(at position: RelativePosition, pageIndex: Int, pageSize: CGSize) -> Annotation? {
            guard let copy = engine?.currentCopy else { return nil }

            let tapX = position.x * pageSize.width
            let tapY = (1 - position.y) * pageSize.height
            let tapPoint = CGPoint(x: tapX, y: tapY)

            // Find the closest annotation within a reasonable distance
            var closestAnnotation: Annotation?
            var closestDistance: CGFloat = .infinity
            let maxDistance: CGFloat = 60 // Maximum tap distance in points

            for annotation in copy.annotations where annotation.position.page == pageIndex && !annotation.content.isDrawing {
                let annX = annotation.position.x * pageSize.width
                let annY = (1 - annotation.position.y) * pageSize.height
                let annPoint = CGPoint(x: annX, y: annY)

                // Calculate distance from tap to annotation center
                let distance = hypot(tapPoint.x - annPoint.x, tapPoint.y - annPoint.y)

                if distance < maxDistance && distance < closestDistance {
                    closestDistance = distance
                    closestAnnotation = annotation
                }
            }

            return closestAnnotation
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let engine = engine,
                  let pdfView = gesture.view as? PDFView,
                  let page = pdfView.currentPage,
                  let doc = pdfView.document,
                  let selectedID = engine.selectedAnnotationID,
                  let copy = engine.currentCopy,
                  let annotation = copy.annotations.first(where: { $0.id == selectedID }) else { return }

            let bounds = page.bounds(for: .mediaBox)
            let pageIndex = doc.index(for: page)

            // Only drag if annotation is on current page
            guard annotation.position.page == pageIndex else { return }

            switch gesture.state {
            case .began:
                dragStartPosition = annotation.position

            case .changed:
                guard let startPos = dragStartPosition else { return }
                let translation = gesture.translation(in: pdfView)

                // Convert translation to PDF coordinates
                let scaleFactor = pdfView.scaleFactor
                let deltaX = translation.x / scaleFactor / bounds.width
                let deltaY = -translation.y / scaleFactor / bounds.height

                let newX = max(0, min(1, startPos.x + deltaX))
                let newY = max(0, min(1, startPos.y + deltaY))

                let newPosition = RelativePosition(x: newX, y: newY, page: pageIndex)
                engine.moveAnnotation(id: selectedID, to: newPosition)
                refreshOverlays()

            case .ended, .cancelled:
                dragStartPosition = nil

            default:
                break
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let pdfView = pdfView,
                  let window = pdfView.window else { return true }

            // Get the touch location in window coordinates
            let locationInWindow = touch.location(in: window)

            // Use hitTest to find which view should actually receive this touch
            guard let hitView = window.hitTest(locationInWindow, with: nil) else { return true }

            // Check if the hit view is part of the PDFView hierarchy
            var view: UIView? = hitView
            while let current = view {
                if current === pdfView {
                    // Touch is within PDFView - allow gesture
                    return true
                }
                view = current.superview
            }

            // Touch is outside PDFView (e.g., toolbar) - ignore gesture
            return false
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Don't allow simultaneous recognition to prevent zoom conflicts
            return false
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Our gestures take priority over PDFView's built-in gestures
            if gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UITapGestureRecognizer {
                return true
            }
            return false
        }
    }
}

// MARK: - Annotation Page View (Reactive overlay)

struct AnnotationPageView: View {
    @Environment(GradingEngine.self) private var engine

    let pageIndex: Int
    let pageSize: CGSize

    var body: some View {
        ZStack {
            if let copy = engine.currentCopy {
                // Final grade
                if let pos = copy.totalPosition, pos.page == pageIndex {
                    DraggablePositionedBadge(
                        element: .total,
                        position: pos,
                        pageSize: pageSize
                    ) {
                        TotalBadge(
                            total: copy.total,
                            maxTotal: copy.maxTotal,
                            percentage: copy.percentage,
                            isHighlighted: engine.positioningElement == .total,
                            date: copy.updatedAt
                        )
                    }
                    .position(x: pos.x * pageSize.width, y: (1 - pos.y) * pageSize.height)
                }

                // Section subtotals
                ForEach(copy.sections.filter { $0.position?.page == pageIndex }) { section in
                    if let pos = section.position {
                        DraggablePositionedBadge(
                            element: .section(id: section.id),
                            position: pos,
                            pageSize: pageSize
                        ) {
                            SectionBadge(
                                section: section,
                                isHighlighted: engine.positioningElement == .section(id: section.id)
                            )
                        }
                        .position(x: pos.x * pageSize.width, y: (1 - pos.y) * pageSize.height)
                    }
                }

                // Positioned questions
                ForEach(copy.allQuestions.filter { $0.position?.page == pageIndex }) { question in
                    if let pos = question.position {
                        DraggablePositionedBadge(
                            element: .question(id: question.id),
                            position: pos,
                            pageSize: pageSize
                        ) {
                            QuestionBadge(
                                question: question,
                                isHighlighted: engine.positioningElement == .question(id: question.id)
                            )
                        }
                        .position(x: pos.x * pageSize.width, y: (1 - pos.y) * pageSize.height)
                    }
                }

                // Annotations (stamps and texts)
                ForEach(copy.annotations.filter { $0.position.page == pageIndex && !$0.content.isDrawing }) { annotation in
                    AnnotationBadge(annotation: annotation, pageSize: pageSize)
                        .position(
                            x: annotation.position.x * pageSize.width,
                            y: (1 - annotation.position.y) * pageSize.height
                        )
                }

            }
        }
        .frame(width: pageSize.width, height: pageSize.height)
    }
}

// MARK: - Draggable Positioned Badge

private struct DraggablePositionedBadge<Content: View>: View {
    @Environment(GradingEngine.self) private var engine
    let element: PositionableElement
    let position: RelativePosition
    let pageSize: CGSize
    let content: Content

    @GestureState private var dragOffset: CGSize = .zero

    init(
        element: PositionableElement,
        position: RelativePosition,
        pageSize: CGSize,
        @ViewBuilder content: () -> Content
    ) {
        self.element = element
        self.position = position
        self.pageSize = pageSize
        self.content = content()
    }

    var body: some View {
        content
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        if engine.selectedTool == .select {
                            state = value.translation
                        }
                    }
                    .onEnded { value in
                        guard engine.selectedTool == .select else { return }

                        let currentX = position.x * pageSize.width
                        let currentY = (1 - position.y) * pageSize.height
                        let newX = (currentX + value.translation.width) / pageSize.width
                        let newY = 1 - (currentY + value.translation.height) / pageSize.height

                        let newPosition = RelativePosition(
                            x: max(0, min(1, newX)),
                            y: max(0, min(1, newY)),
                            page: position.page
                        )
                        engine.positionElement(element, at: newPosition)
                    }
            )
    }
}

// MARK: - Total Badge

private struct TotalBadge: View {
    let total: Double
    let maxTotal: Double
    let percentage: Double
    let isHighlighted: Bool
    let date: Date

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Label
            Text("FINAL")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.red)
                .tracking(0.5)

            Divider().frame(height: 24)

            // Score
            Text("\(NumberFormatter.format(total))/\(NumberFormatter.format(maxTotal))")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.red)

            // Percentage
            Text("\(Int(percentage))%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.red.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.1))
                .clipShape(Capsule())

            Divider().frame(height: 24)

            // Date
            Text(dateString)
                .font(.system(size: 9))
                .foregroundColor(.red.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.white)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHighlighted ? Color.orange : Color.red, lineWidth: isHighlighted ? 3 : 2)
        )
    }
}

// MARK: - Question Badge

private struct QuestionBadge: View {
    let question: Question
    let isHighlighted: Bool

    // Color pill - uses stamp color if present, otherwise status color
    private var pillColor: Color {
        if let stampColor = question.stampColor {
            return Color(hex: stampColor.hex)
        } else {
            return Color(hex: question.status.color)
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            // Score box with red border
            HStack(spacing: 5) {
                Text("\(NumberFormatter.format(question.points ?? 0))/\(NumberFormatter.format(question.maxPoints))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.red)

                Circle()
                    .fill(pillColor)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isHighlighted ? Color.orange : Color.red, lineWidth: isHighlighted ? 3 : 1.5)
            )

            // Stamp text below (if present)
            if let stampText = question.stampText {
                Text(stampText)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
    }
}

// MARK: - Section Badge

private struct SectionBadge: View {
    let section: Section
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("Subscore: \(section.name)")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.red.opacity(0.8))

            Text("\(NumberFormatter.format(section.subtotal))/\(NumberFormatter.format(section.maxSubtotal))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(.white)
                .shadow(color: .black.opacity(0.15), radius: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isHighlighted ? Color.orange : Color.red, lineWidth: isHighlighted ? 3 : 1.5)
        )
    }
}

// MARK: - Annotation Badge

private struct AnnotationBadge: View {
    @Environment(GradingEngine.self) private var engine
    let annotation: Annotation
    let pageSize: CGSize

    @State private var editText: String = ""
    @State private var dragOffset: CGSize = .zero
    @FocusState private var isTextFieldFocused: Bool

    private var isSelected: Bool {
        engine.selectedAnnotationID == annotation.id
    }

    private var isEditing: Bool {
        engine.inlineEditingAnnotationID == annotation.id
    }

    var body: some View {
        annotationContent
            .overlay(selectionOverlay)
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if isSelected || isEditing {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        if isSelected || isEditing {
                            // Calculate new position
                            let currentX = annotation.position.x * pageSize.width
                            let currentY = (1 - annotation.position.y) * pageSize.height

                            let newX = (currentX + value.translation.width) / pageSize.width
                            let newY = 1 - (currentY + value.translation.height) / pageSize.height

                            let clampedX = max(0, min(1, newX))
                            let clampedY = max(0, min(1, newY))

                            let newPosition = RelativePosition(
                                x: clampedX,
                                y: clampedY,
                                page: annotation.position.page
                            )

                            engine.moveAnnotation(id: annotation.id, to: newPosition)
                            dragOffset = .zero
                        }
                    }
            )
    }

    @ViewBuilder
    private var annotationContent: some View {
        switch annotation.content {
        case .text(let text):
            if isEditing {
                // Inline editing mode
                TextField("Comment...", text: $editText, axis: .vertical)
                    .font(.system(size: 12))
                    .foregroundStyle(.black)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 120, maxWidth: 250)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.yellow)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange, lineWidth: 2)
                    )
                    .focused($isTextFieldFocused)
                    .onAppear {
                        editText = text
                        // Small delay to ensure the view is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                        }
                    }
                    .onSubmit {
                        commitEdit()
                    }
                    .onChange(of: isTextFieldFocused) { _, focused in
                        if !focused {
                            commitEdit()
                        }
                    }
                    .onChange(of: editText) { _, newValue in
                        engine.updateTextAnnotation(id: annotation.id, text: newValue)
                    }
            } else {
                // Display mode
                Text(text.isEmpty ? " " : text)
                    .font(.system(size: 10))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 200)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.yellow.opacity(0.9))
                            .shadow(color: .black.opacity(0.15), radius: 2)
                    )
            }

        case .stamp(_, let text, let color):
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: color.hex))
                        .shadow(color: .black.opacity(0.2), radius: 2)
                )

        case .drawing:
            EmptyView()
        }
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected && !isEditing {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.blue, lineWidth: 2)
                .padding(-2)
        }
    }

    private func commitEdit() {
        engine.finishInlineEditing()
    }
}


