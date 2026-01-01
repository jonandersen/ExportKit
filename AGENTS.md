
## Project Overview

Mealheim is a meal planning iOS app built with **SwiftUI**. The app helps users maintain a meal library and plan meals with automatic generation capabilities.

## Common Commands

Use `xcsift` to simplify outp

### Building
```bash
# Build the project
xcodebuild -project ExportKitDemoApp.xcodeproj -scheme ExportKitDemoApp -destination 'platform=iOS Simulator,name=iPhone 17  2>&1 | xcsift'

# Clean build
xcodebuild clean -project ExportKitDemoApp.xcodeproj -scheme ExportKitDemoApp  2>&1 | xcsift
```

The project uses Swift Testing framework (not XCTest), so tests use `@Test` annotations instead of XCTestCase classes.

### Formatting
Run this after you are done making changes to the codebase (e.g test/builds are passing)
```bash
# Format the codebase
swiftformat .
```