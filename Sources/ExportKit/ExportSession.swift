import Foundation
@preconcurrency import AVFoundation
import CoreGraphics
import SwiftUI

public struct ExportSession {

    enum ExportError: Error, LocalizedError {
        case failedToCreateComposition
        case failedToCreateExportSession
        case exportFailed(Error?)
        case invalidAsset

        var errorDescription: String? {
            switch self {
            case .failedToCreateComposition:
                return "Failed to create video composition for export."
            case .failedToCreateExportSession:
                return "Failed to create export session."
            case .exportFailed(let underlyingError):
                return "Video export failed: \(underlyingError?.localizedDescription ?? "Unknown reason")"
            case .invalidAsset:
                return "The provided AVAsset is invalid or could not load tracks."
            }
        }
    }

    private var aspectRatio: AspectRatio? = nil
    private var rotation: Rotation = .zero            // Default rotation
    private var offset: CGSize = .zero               // Default offset
    private var progressHandler: (@MainActor @Sendable (Double) -> Void)? = nil
    private var trimRange: CMTimeRange?
    private var metadataItems: [AVMetadataItem] = []
    
    public init() {}

    public func aspectRatio(_ ratio: AspectRatio) -> Self {
        var newSession = self
        newSession.aspectRatio = ratio
        return newSession
    }

    public func rotation(_ rot: Rotation) -> Self {
        var newSession = self
        newSession.rotation = rot
        return newSession
    }

    public func offset(_ off: CGSize) -> Self {
        var newSession = self
        newSession.offset = off
        return newSession
    }

    public func progressHandler(_ handler: (@MainActor @Sendable (Double) -> Void)?) -> Self {
        var newSession = self
        newSession.progressHandler = handler
        return newSession
    }

    public func metadata(_ items: [AVMetadataItem]) -> Self {
        var newSession = self
        newSession.metadataItems = items
        return newSession
    }

    public func trim(start: Double, duration: Double) -> Self {
        var newSession = self
        let startTime = CMTime(seconds: start, preferredTimescale: 600) // Use a common timescale like 600
        let durationTime = CMTime(seconds: duration, preferredTimescale: 600)
        newSession.trimRange = CMTimeRange(start: startTime, duration: durationTime)
        return newSession
    }
    
    public func export(asset avAsset: AVAsset) async throws -> URL {
        return try await Export(aspectRatio: aspectRatio, rotation: rotation, offset: offset, progressHandler: progressHandler, trimRange: trimRange, metadataItems: metadataItems, asset: avAsset)
            .export()
    }

    nonisolated struct Export {
        let aspectRatio: AspectRatio?
        let rotation: Rotation
        let offset: CGSize
        let progressHandler: (@MainActor @Sendable (Double) -> Void)?
        let trimRange: CMTimeRange?
        let metadataItems: [AVMetadataItem]
        let asset: AVAsset
        
        func export() async throws -> URL {
            // 1. Create unique output URL
            let outputFileName = UUID().uuidString + ".mp4"
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(outputFileName)

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }

            // 3. Create Composition
            let composition = AVMutableComposition()

            // 4. Add Video Track
            guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first,
                  let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw ExportError.failedToCreateComposition
            }

            // Load timeRange, naturalSize, nominalFrameRate, minFrameDuration, and preferredTransform
            let (timeRange, naturalSizeNotTransformed, nominalFrameRate, minFrameDuration, sourcePreferredTransform) = try await sourceVideoTrack.load(.timeRange, .naturalSize, .nominalFrameRate, .minFrameDuration, .preferredTransform)

            // Apply the transform to get the correctly oriented size and ensure dimensions are positive
            let transformedSize = naturalSizeNotTransformed.applying(sourcePreferredTransform)
            let naturalSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

            // Determine the best frame duration:
            // 1. Use nominalFrameRate if valid (> 0)
            // 2. Fallback to minFrameDuration if valid and positive
            // 3. Default to 30fps if neither is valid
            let frameDuration: CMTime
            if nominalFrameRate > 0 {
                frameDuration = CMTimeMakeWithSeconds(1.0 / Double(nominalFrameRate),
                                                          preferredTimescale: 600)
            } else if minFrameDuration.isValid && minFrameDuration.seconds > 0 {
                frameDuration = minFrameDuration
            } else {
                frameDuration = CMTime(value: 1, timescale: 30) // Default to 30 FPS
            }

            // Ensure the track gets inserted correctly using its original time range
            try compositionVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)

            // 5. Create Video Composition
            let videoComposition = AVMutableVideoComposition()
            videoComposition.frameDuration = frameDuration // Use determined frame duration

            let aspectRatio = aspectRatio ?? AspectRatio.from(size: naturalSize)
            // 6. Calculate Render Size
            let renderSize = calculateRenderSize(aspectRatio: aspectRatio, originalSize: naturalSize)
            videoComposition.renderSize = renderSize

            // 7. Create Instructions
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = timeRange // Use the original full time range for the instruction

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)

            // 8. Calculate Transform
            let transform = sourcePreferredTransform
                .concatenating(
                    VideoTransformer(videoSize: naturalSize, compositionSize: renderSize)
                        .rotated(by: rotation)
                        .offset(by: offset)
                        .transform
                )
            layerInstruction.setTransform(transform, at: .zero)

            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            
            // Add Audio Tracks
            let sourceAudioTracks = try await asset.loadTracks(withMediaType: .audio)
            for sourceAudioTrack in sourceAudioTracks {
                if let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid)
                {
                    do {
                        // Use the original track time range for insertion
                        let (isEnabled, audioTimeRange) = try await sourceAudioTrack.load(.isEnabled,.timeRange)
                        try compositionAudioTrack.insertTimeRange(audioTimeRange, of: sourceAudioTrack, at: .zero)
                        compositionAudioTrack.isEnabled = isEnabled
                    } catch {
                        // Log or handle error adding specific audio track, but continue if possible
                        print("Warning: Could not add audio track \(sourceAudioTrack.trackID): \(error.localizedDescription)")
                    }
                }
            }

            // 9. Create Export Session
            guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                throw ExportError.failedToCreateExportSession
            }
            exportSession.videoComposition = videoComposition

            // Apply trim range directly to the export session if it exists
            if let trimRange = self.trimRange {
                exportSession.timeRange = trimRange
            }

            // Combine existing metadata with new metadata
            let existingMetadata = try await asset.load(.metadata)
            exportSession.metadata = existingMetadata + metadataItems
            

            // 10. Monitor Progress (if handler provided)
            let progressTask: Task<Void, Never>?
            if let progressHandler {
                let states = exportSession.states(updateInterval: 0.1)
                progressTask = Task { @Sendable in
                     for await state in states {
                        if case .exporting(let progress) = state {
                            await progressHandler(Double(progress.fractionCompleted))
                        }
                    }
                }
            } else {
                progressTask = nil
            }

            // 11. Start Export
            do {
                try await exportSession.export(to: outputURL, as: .mp4)
                progressTask?.cancel() // Ensure progress task is cancelled on completion
                await progressHandler?(1.0) // Signal completion
            } catch {
                progressTask?.cancel() // Ensure progress task is cancelled on error
                throw ExportError.exportFailed(error)
            }

            return outputURL
            
        }

        // Calculate the actual output dimensions based on the aspect ratio while preserving original resolution
        private func calculateRenderSize(aspectRatio: AspectRatio, originalSize: CGSize) -> CGSize {
            let originalPixelCount = originalSize.width * originalSize.height
            if aspectRatio == .portrait {
                // 9:16 ratio
                let height = sqrt(originalPixelCount * 16 / 9)
                let width = height * 9 / 16
                return CGSize(width: width, height: height)
            } else if aspectRatio == .landscape {
                // 16:9 ratio
                let width = sqrt(originalPixelCount * 16 / 9)
                let height = width * 9 / 16
                return CGSize(width: width, height: height)
            } else { // .square
                // 1:1 ratio
                let dimension = sqrt(originalPixelCount)
                return CGSize(width: dimension, height: dimension)
            }
        }
    }
}
