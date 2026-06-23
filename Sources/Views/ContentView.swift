import PhotosUI
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CaptionViewModel()
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    picker

                    if viewModel.isWorking {
                        ProgressView(viewModel.statusMessage)
                            .frame(maxWidth: .infinity)
                    } else if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    if !viewModel.segments.isEmpty {
                        styleSection
                        burnButton
                        segmentPreview
                    }

                    if let outputURL = viewModel.outputURL {
                        ShareLink(item: outputURL) {
                            Label("書き出した動画を共有", systemImage: "square.and.arrow.up")
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("Caption")
            .onChange(of: pickerItem) { _, newValue in
                guard let newValue else { return }
                Task { await viewModel.handlePicked(newValue) }
            }
        }
    }

    private var picker: some View {
        PhotosPicker(selection: $pickerItem, matching: .videos) {
            Label(viewModel.hasVideo ? "別の動画を選ぶ" : "動画を選ぶ",
                  systemImage: "video.badge.plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isWorking)
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("スタイル")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CaptionStyle.presets) { preset in
                        Button {
                            viewModel.selectedStyleID = preset.id
                        } label: {
                            Text(preset.name)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    viewModel.selectedStyleID == preset.id
                                        ? Color.accentColor.opacity(0.2)
                                        : Color.secondary.opacity(0.12)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(viewModel.selectedStyleID == preset.id
                                                ? Color.accentColor : Color.clear,
                                                lineWidth: 2)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var burnButton: some View {
        Button {
            Task { await viewModel.burn() }
        } label: {
            Label("字幕を焼き込む", systemImage: "text.below.photo")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isWorking)
    }

    private var segmentPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("字幕プレビュー")
                .font(.headline)
            ForEach(viewModel.segments) { segment in
                HStack(alignment: .top, spacing: 8) {
                    Text(timecode(segment.start))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text(segment.text)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timecode(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

#Preview {
    ContentView()
}
