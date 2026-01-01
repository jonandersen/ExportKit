import AVFoundation
import CoreGraphics

struct VideoTransformer {
    let videoSize: CGSize
    let compositionSize: CGSize
    var rotation: Rotation = .zero
    var position: CGSize = .zero // Represents fractional offset

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
        newTransformer.position = position
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

        // Calculate the scaled video dimensions
        let scaledVideoWidth = rotatedVideoSize.width * scaleFactor
        let scaledVideoHeight = rotatedVideoSize.height * scaleFactor

        // Calculate available panning range (how much the scaled video extends beyond composition)
        let availableHorizontalPan = max(0, (scaledVideoWidth - compositionSize.width) / 2)
        let availableVerticalPan = max(0, (scaledVideoHeight - compositionSize.height) / 2)

        // Convert normalized position [-1, +1] to actual translation
        // -1 = top/left edge, 0 = center, +1 = bottom/right edge
        // Invert Y-axis: SwiftUI Y increases upwards, AVFoundation Y increases downwards
        let positionOffsetX = position.width * availableHorizontalPan
        let positionOffsetY = -position.height * availableVerticalPan

        let positionTransform = CGAffineTransform(translationX: positionOffsetX, y: positionOffsetY)

        // Combine transforms
        let composite = rotationTransform
            .concatenating(scaleTransform)
            .concatenating(translationTransform)
            .concatenating(positionTransform) // Apply position offset last

        return composite
    }
}
