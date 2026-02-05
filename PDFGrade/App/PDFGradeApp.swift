//
//  PDFGradeApp.swift
//  PDFGrade
//

import SwiftUI

@main
struct PDFGradeApp: App {
    @State private var engine = GradingEngine()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(engine)
        }
    }
}
