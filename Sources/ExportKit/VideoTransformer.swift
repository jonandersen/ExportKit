import CoreGraphics
import AVFoundation

struct VideoTransformer {
    let videoSize: CGSize
    let compositionSize: CGSize
    var rotation: Rotation = .zero
    var offset: CGSize = .zero // Represents fractional offset

    // Initializer
    init(videoSize: CGSize, compositionSize: CGSize) {
        self.videoSize = videoSize
        self.compositionSize = compositionSize
    }

    // Builder-style methods
    func rotated(by rotation: Rotation) -> VideoTransformer {
        var newTransformer = self
        newTransformer.rotation = rotation
        return newTransformer
    }

    func offset(by offset: CGSize) -> VideoTransformer {
        var newTransformer = self
        newTransformer.offset = offset
        return newTransformer
    }

    // Computed property to calculate the final transform
    var transform: CGAffineTransform {
        // Logic from the original compositeTransform function

        // Determine the size of the video after rotation.
        // For 90° and 270° rotations, width and height swap.
        let rotatedVideoSize: CGSize
        switch rotation {
        case .zero, .oneEighty:
            rotatedVideoSize = videoSize
        case .ninety, .twoSeventy:
            rotatedVideoSize = CGSize(width: videoSize.height, height: videoSize.width)
        }

        // Compute the aspect fill scale factor.
        // This ensures the rotated video covers the entire composition.
        let scaleFactor = max(compositionSize.width / rotatedVideoSize.width,
                              compositionSize.height / rotatedVideoSize.height)

        // Compute centers.
        let videoCenter = CGPoint(x: videoSize.width / 2, y: videoSize.height / 2)
        let compositionCenter = CGPoint(x: compositionSize.width / 2, y: compositionSize.height / 2)

        // Compute the rotated center relative to the origin.
        let rotatedCenter: CGPoint
        switch rotation {
        case .zero:
            rotatedCenter = videoCenter
        case .ninety:
            rotatedCenter = CGPoint(x: -videoSize.height / 2, y: videoSize.width / 2)
        case .oneEighty:
            rotatedCenter = CGPoint(x: -videoSize.width / 2, y: -videoSize.height / 2)
        case .twoSeventy:
            rotatedCenter = CGPoint(x: videoSize.height / 2, y: -videoSize.width / 2)
        }

        // Scale the rotated center.
        let scaledRotatedCenter = CGPoint(x: rotatedCenter.x * scaleFactor,
                                          y: rotatedCenter.y * scaleFactor)

        // Calculate translation needed to move the scaled rotated center to the composition's center.
        let tx = compositionCenter.x - scaledRotatedCenter.x
        let ty = compositionCenter.y - scaledRotatedCenter.y

        // Build the composite transform:
        // 1. Rotate about the origin.
        // 2. Scale.
        // 3. Translate to re-center.
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat(rotation.radians))
        let scaleTransform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        let translationTransform = CGAffineTransform(translationX: tx, y: ty)

        // Convert fractional offset to points relative to composition size.
        // Invert Y-axis assuming SwiftUI gesture Y increases upwards,
        // while AVFoundation layer transform Y increases downwards.
        var dragX: CGFloat
        var dragY: CGFloat

        switch rotation {
        case .ninety, .twoSeventy:
            // Rotated 90/270: Drag X maps to composition height, Drag Y maps to composition width
            dragX = offset.width * compositionSize.height * scaleFactor
            dragY = -offset.height * compositionSize.width * scaleFactor // Invert Y
        case .zero, .oneEighty:
            // Rotated 0/180: Drag X maps to composition width, Drag Y maps to composition height
            dragX = offset.width * compositionSize.width * scaleFactor
            dragY = -offset.height * compositionSize.height * scaleFactor // Invert Y
        }

        let dragTransform = CGAffineTransform(translationX: dragX, y: dragY)

        // Combine transforms
        let composite = rotationTransform
            .concatenating(scaleTransform)
            .concatenating(translationTransform)
            .concatenating(dragTransform) // Apply drag last

        return composite
    }
}
