# PDFGrade

A native iOS/iPadOS application for grading PDF documents with an intuitive annotation system. Built with SwiftUI and designed for educators who need to grade student submissions efficiently.

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B%20%7C%20iPadOS%2017%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-GPLv3-blue)

## Features

### PDF Annotation

- **Score Badges**: Place grade indicators directly on the PDF at specific locations
- **Text Comments**: Add inline text annotations for detailed feedback
- **Stamps**: Create custom stamps with colors and coefficients for quick marking
- **Drag & Drop**: Reposition all annotations with intuitive gestures

### Rubric Management

- **Hierarchical Structure**: Organize grading criteria into sections and questions
- **Flexible Scoring**: Support for partial points with 0.5 increments
- **Import/Export**: Share rubric templates between projects as JSON files
- **Batch Apply**: Apply a rubric to multiple student submissions at once

### Export

- **Graded PDF Export**: Generate final PDFs with all annotations baked in
- **Clean Output**: Professional-looking grade stamps and comments

## Architecture

PDFGrade follows a **modular MVVM architecture** with clear separation of concerns:

```
PDFGrade/
├── Core/
│   └── Theme/              # Design system (spacing, colors, typography)
├── Engine/
│   ├── GradingEngine.swift # Core domain logic (@Observable)
│   └── PDFExporter.swift   # PDF generation
├── Models/
│   └── CopyFeedback.swift  # Data models
├── ViewModels/
│   └── GradingViewModel.swift # View state management
└── Views/
    ├── Grading/
    │   ├── GradingView.swift          # Main container
    │   └── Components/
    │       ├── FloatingToolbar.swift  # Annotation tools
    │       ├── PDFContainerView.swift # PDF display
    │       ├── SidebarView.swift      # Tab navigation
    │       ├── EvaluationComponents.swift
    │       ├── RubricComponents.swift
    │       └── ...
    └── PDFAnnotatedView.swift  # UIKit/SwiftUI bridge
```

### Why This Architecture?

1. **MVVM with @Observable**: Leverages Swift's modern observation framework for reactive UI updates without the boilerplate of Combine publishers.

2. **Modular Components**: Each UI component is self-contained and reusable, following Atomic Design principles. This makes the codebase easier to maintain and test.

3. **Design System**: Centralized theme constants ensure visual consistency and make global style changes trivial.

4. **Separation of Concerns**:
   - `GradingEngine`: Pure domain logic (grading calculations, data mutations)
   - `GradingViewModel`: View-specific state (navigation, alerts, sheet presentation)
   - Views: Pure UI rendering

## Requirements

- iOS 17.0+ / iPadOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository:

```bash
git clone https://github.com/vincentchoqueuse/PDFGrade.git
cd PDFGrade
```

2. Open the project in Xcode:

```bash
open PDFGrade.xcodeproj
```

3. Select your target device or simulator

4. Build and run (⌘R)

## Usage

### Getting Started

1. **Import a PDF**: Use the document picker to select a PDF file for grading
2. **Create a Rubric**: Navigate to the "Rubric" tab and add sections/questions
3. **Grade**: Switch to "Evaluation" tab to assign scores and add feedback
4. **Position Scores**: Tap the pin icon to place score badges on the PDF
5. **Export**: Generate the final graded PDF for distribution

### Keyboard Shortcuts (iPad)

| Shortcut | Action            |
| -------- | ----------------- |
| ⌘S       | Save current copy |
| ⌘E       | Export PDF        |
| ⌘←       | Previous page     |
| ⌘→       | Next page         |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add DocC comments for public APIs
- Keep functions focused and under 30 lines when possible

## License

This project is licensed under the GNU GPLv3 License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [PDFKit](https://developer.apple.com/documentation/pdfkit) for PDF rendering
- Icons from [SF Symbols](https://developer.apple.com/sf-symbols/)
