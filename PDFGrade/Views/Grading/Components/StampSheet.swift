//
//  StampSheet.swift
//  PDFGrade
//
//  Sheet for creating new stamp definitions
//

import SwiftUI

/// Sheet view for creating a new stamp definition
struct NewStampSheet: View {
    @Environment(\.dismiss) private var dismiss
    let engine: GradingEngine

    @State private var text = ""
    @State private var color: StampColor = .yellow
    @State private var coefficient: Double = 0.5

    var body: some View {
        NavigationStack {
            Form {
                textSection
                colorSection
                coefficientSection
            }
            .navigationTitle("New Stamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addStamp() }
                        .disabled(text.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Sections

    private var textSection: some View {
        TextField("Stamp text", text: $text)
    }

    private var colorSection: some View {
        Picker("Color", selection: $color) {
            ForEach(StampColor.allCases, id: \.self) { c in
                HStack {
                    Circle()
                        .fill(Color(hex: c.hex))
                        .frame(width: 16, height: 16)
                    Text(c.label)
                }
                .tag(c)
            }
        }
    }

    private var coefficientSection: some View {
        VStack {
            HStack {
                Text("Coefficient")
                Spacer()
                Text("\(Int(coefficient * 100))%")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $coefficient, in: 0...1, step: 0.25)
        }
    }

    // MARK: - Actions

    private func addStamp() {
        engine.addStampDefinition(text: text, color: color, coefficient: coefficient)
        dismiss()
    }
}
