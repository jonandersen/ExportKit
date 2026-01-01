//
//  ContentView.swift
//  ExportKitDemoApp
//
//  Created by Jon Andersen on 12/31/25.
//

import AVFoundation
import AVKit
import ExportKit
import PhotosUI
import SwiftUI

struct VideoAsset: Transferable {
    let avAsset: AVAsset

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile((video.avAsset as! AVURLAsset).url)
        } importing: { received in
            VideoAsset(avAsset: AVURLAsset(url: received.file))
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoAsset: AVAsset?
    @State private var videoDuration: Double = 0
    @State private var isLoadingVideo = false

    // Export parameters
    @State private var aspectRatio: AspectRatio = .landscape
    @State private var rotation: Rotation = .zero
    @State private var offsetX: Double = 0.0
    @State private var offsetY: Double = 0.0
    @State private var trimStart: Double = 0.0
    @State private var trimDuration: Double = 0.0

    // Export state
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var exportedVideoURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Video Picker
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .videos
                    ) {
                        Label("Select Video", systemImage: "video.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            await loadVideo(newItem)
                        }
                    }

                    if isLoadingVideo {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("Loading video...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if videoAsset != nil {
                        Divider()

                        // Aspect Ratio Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Aspect Ratio")
                                .font(.headline)

                            Picker("Aspect Ratio", selection: $aspectRatio) {
                                Text("Portrait (9:16)").tag(AspectRatio.portrait)
                                Text("Landscape (16:9)").tag(AspectRatio.landscape)
                                Text("Square (1:1)").tag(AspectRatio.square)
                            }
                            .pickerStyle(.segmented)
                        }

                        // Rotation Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rotation")
                                .font(.headline)

                            Picker("Rotation", selection: $rotation) {
                                Text("0°").tag(Rotation.zero)
                                Text("90°").tag(Rotation.ninety)
                                Text("180°").tag(Rotation.oneEighty)
                                Text("270°").tag(Rotation.twoSeventy)
                            }
                            .pickerStyle(.segmented)
                        }

                        // Offset Controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Offset X: \(offsetX, specifier: "%.2f")")
                                .font(.headline)

                            Slider(value: $offsetX, in: -1.0 ... 1.0)

                            Text("Offset Y: \(offsetY, specifier: "%.2f")")
                                .font(.headline)

                            Slider(value: $offsetY, in: -1.0 ... 1.0)
                        }

                        // Trim Range Controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trim Start: \(trimStart, specifier: "%.1f")s")
                                .font(.headline)

                            Slider(
                                value: $trimStart,
                                in: 0 ... max(0, videoDuration - trimDuration)
                            )

                            Text("Duration: \(trimDuration, specifier: "%.1f")s")
                                .font(.headline)

                            Slider(
                                value: $trimDuration,
                                in: 0.1 ... max(0.1, videoDuration - trimStart)
                            )
                        }

                        Divider()

                        // Export Button
                        Button {
                            Task {
                                await exportVideo()
                            }
                        } label: {
                            if isExporting {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                    Text("Exporting... \(Int(exportProgress * 100))%")
                                }
                            } else {
                                Label("Export & Preview", systemImage: "play.circle.fill")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isExporting ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(isExporting)

                        // Progress Bar
                        if isExporting {
                            ProgressView(value: exportProgress)
                                .progressViewStyle(.linear)
                        }

                        // Error Message
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }

                        // Video Player
                        if let exportedVideoURL {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Exported Video")
                                    .font(.headline)

                                VideoPlayer(player: AVPlayer(url: exportedVideoURL))
                                    .frame(height: 300)
                                    .cornerRadius(10)
                            }
                        }
                    } else {
                        Text("Select a video to get started")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("ExportKit Demo")
        }
    }

    private func loadVideo(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        isLoadingVideo = true
        errorMessage = nil

        do {
            guard let movie = try await item.loadTransferable(type: VideoAsset.self) else {
                errorMessage = "Failed to load video"
                isLoadingVideo = false
                return
            }

            videoAsset = movie.avAsset
            let duration = try await movie.avAsset.load(.duration)
            videoDuration = duration.seconds
            trimDuration = duration.seconds
            exportedVideoURL = nil
        } catch {
            errorMessage = "Error loading video: \(error.localizedDescription)"
        }

        isLoadingVideo = false
    }

    private func exportVideo() async {
        guard let videoAsset else { return }

        isExporting = true
        exportProgress = 0.0
        errorMessage = nil
        exportedVideoURL = nil

        do {
            let session = ExportSession()
                .aspectRatio(aspectRatio)
                .rotation(rotation)
                .offset(CGSize(width: offsetX, height: offsetY))
                .trim(start: trimStart, duration: trimDuration)
                .progressHandler { progress in
                    exportProgress = progress
                }

            let outputURL = try await session.export(asset: videoAsset)
            exportedVideoURL = outputURL
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }

        isExporting = false
    }
}

#Preview {
    ContentView()
}
