# ExportKit

A lightweight Swift framework for video export that makes customizing aspect ratios, rotations, and transformations simple.

[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platforms-iOS%2015.0+-lightgrey.svg)](https://developer.apple.com/swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- Export videos with custom aspect ratios (portrait, landscape, square)
- Apply rotation transformations (0°, 90°, 180°, 270°)
- Add offset transformations
- Monitor export progress

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ExportKit.git", from: "0.1.0")
]
```

## Usage

ExportKit provides a simple, chainable API to configure and run video exports.

### Basic Export

```swift
import ExportKit
import AVFoundation

// Create a session and export with default settings
let asset = AVAsset(url: videoURL)
let exportSession = ExportSession()
let outputURL = try await exportSession.export(asset: asset)
```

### Setting Aspect Ratio

```swift
// Supported ratios: .portrait (9:16), .landscape (16:9), .square (1:1)
let exportSession = ExportSession()
    .aspectRatio(.square)
```

### Adding Rotation

```swift
// Supported rotations: .zero, .ninety, .oneEighty, .twoSeventy
let exportSession = ExportSession()
    .rotation(.ninety)
```

### Adding Offset

```swift
// Apply positional offset
let exportSession = ExportSession()
    .offset(CGSize(width: 20, height: 0))
```

### Monitoring Progress

```swift
let exportSession = ExportSession()
    .progressHandler { progress in
        print("Export progress: \(Int(progress * 100))%")
    }
    .export(asset: asset)
```

### Chaining Options

```swift
// Options can be chained together
let exportSession = ExportSession()
    .aspectRatio(.portrait)
    .rotation(.ninety)
    .offset(CGSize(width: 10, height: -15))
    .progressHandler { progress in
        print("Export progress: \(Int(progress * 100))%")
    }

let outputURL = try await exportSession.export(asset: asset)
```

### Error Handling

```swift
do {
    let exportSession = ExportSession()
        .aspectRatio(.landscape)
    
    let outputURL = try await exportSession.export(asset: asset)
    // Use the exported video file
} catch let error as ExportSession.ExportError {
    switch error {
    case .failedToCreateComposition:
        print("Failed to create composition")
    case .failedToCreateExportSession:
        print("Failed to create export session")
    case .exportFailed(let underlyingError):
        print("Export failed: \(underlyingError?.localizedDescription ?? "Unknown")")
    case .invalidAsset:
        print("The asset is invalid")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## License

ExportKit is available under the MIT license. See the LICENSE file for more info. 
