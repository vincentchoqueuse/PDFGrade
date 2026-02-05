//
//  Theme.swift
//  PDFGrade
//
//  Design System - Centralized styling constants
//

import SwiftUI

// MARK: - Spacing

/// Standardized spacing values following an 8pt grid system
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Corner Radius

/// Standardized corner radius values
enum CornerRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
}

// MARK: - Icon Size

/// Standardized icon sizes
enum IconSize {
    static let xs: CGFloat = 10
    static let sm: CGFloat = 14
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - Component Dimensions

/// Fixed dimensions for common UI components
enum ComponentSize {
    static let buttonMinHeight: CGFloat = 44
    static let toolbarHeight: CGFloat = 50
    static let sidebarWidth: CGFloat = 340
    static let statusIndicator: CGFloat = 14
    static let stampIndicator: CGFloat = 10
    static let controlButton: CGFloat = 24
}

// MARK: - Animation

/// Standardized animation durations
enum AnimationDuration {
    static let fast: Double = 0.15
    static let normal: Double = 0.25
    static let slow: Double = 0.4
}

// MARK: - Shadow

/// Shadow configuration for elevated components
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let subtle = ShadowStyle(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    static let medium = ShadowStyle(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    static let elevated = ShadowStyle(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
}

// MARK: - View Extensions

extension View {
    /// Applies a standardized card background style
    func cardStyle() -> some View {
        self
            .padding(Spacing.lg)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    /// Applies a standardized shadow
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    /// Applies pill/capsule button styling
    func pillStyle(background: Color = Color(uiColor: .tertiarySystemFill)) -> some View {
        self
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs + 2)
            .background(background)
            .clipShape(Capsule())
    }
}

// MARK: - Number Formatting

/// Utility for consistent number formatting across the app
enum NumberFormatter {
    /// Formats a double value with minimal decimal places
    /// - Parameter value: The value to format
    /// - Returns: Formatted string (e.g., "5", "5.5", "5.25")
    static func format(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else if value.truncatingRemainder(dividingBy: 0.1) == 0 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}
