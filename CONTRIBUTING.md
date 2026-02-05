# Contributing to PDFGrade

First off, thank you for considering contributing to PDFGrade! It's people like you that make PDFGrade such a great tool for educators.

## Code of Conduct

By participating in this project, you are expected to uphold our Code of Conduct: be respectful, inclusive, and constructive.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find that the problem has already been reported.

When creating a bug report, please include:

- **Clear title** describing the issue
- **Steps to reproduce** the behavior
- **Expected behavior** vs **actual behavior**
- **Screenshots** if applicable
- **Environment info**: iOS version, device model, app version

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- **Use case**: Why is this enhancement needed?
- **Proposed solution**: How should it work?
- **Alternatives considered**: Other approaches you've thought about

### Pull Requests

1. **Fork** the repository
2. **Create a branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** following our code style
4. **Test** your changes thoroughly
5. **Commit** with clear messages:
   ```bash
   git commit -m "Add: brief description of the change"
   ```
6. **Push** to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
7. **Open a Pull Request** with a clear description

## Development Setup

### Requirements

- macOS 14.0+
- Xcode 15.0+
- iOS 17.0+ Simulator or device

### Getting Started

```bash
git clone https://github.com/YOUR_USERNAME/PDFGrade.git
cd PDFGrade
open PDFGrade.xcodeproj
```

## Code Style Guide

### Swift Guidelines

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful names for variables, functions, and types
- Keep functions focused and under 30 lines when possible
- Prefer immutability (`let` over `var`)

### Documentation

- Add `///` DocC comments for public APIs
- Include parameter descriptions and return values
- Add code examples for complex functionality

### Architecture

- **Views**: Pure UI, no business logic
- **ViewModels**: View state management, navigation
- **Engine**: Core domain logic
- **Models**: Data structures

### File Organization

```swift
// MARK: - Properties

// MARK: - Body / Content

// MARK: - Subviews

// MARK: - Actions

// MARK: - Helpers
```

## Commit Message Format

Use semantic commit messages:

- `Add:` New feature
- `Fix:` Bug fix
- `Update:` Enhancement to existing feature
- `Refactor:` Code restructuring
- `Docs:` Documentation changes
- `Test:` Test additions or fixes
- `Chore:` Maintenance tasks

Example:
```
Add: Export rubric as shareable JSON template

- Implement GradesExporter.exportRubric()
- Add share sheet integration
- Include import functionality
```

## Questions?

Feel free to open an issue with the `question` label if you need help!

---

Thank you for contributing! 🎉
