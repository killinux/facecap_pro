import SwiftUI

struct RecordingsScreen: View {
    @ObservedObject var store: RecordingStore

    var body: some View {
        NavigationStack {
            Group {
                if store.recordings.isEmpty {
                    ContentUnavailableCompat()
                } else {
                    List {
                        ForEach(store.recordings) { meta in
                            NavigationLink(value: meta) {
                                row(meta)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.delete(store.recordings[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("录制")
            .navigationDestination(for: RecordingMeta.self) { meta in
                PlaybackScreen(meta: meta, store: store)
            }
        }
    }

    private func row(_ meta: RecordingMeta) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(meta.createdAt.formatted(date: .abbreviated, time: .standard))
                .font(.headline)
            Text("\(String(format: "%.1f", meta.duration)) 秒 · \(meta.frameCount) 帧 · \(meta.mode == "fusion" ? "融合模式" : "MediaPipe")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ContentUnavailableCompat: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "video.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("还没有录制")
                .font(.headline)
            Text("在捕捉页点击红色按钮开始录制表情动画")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// 回放：3D 头像重演录制的表情 + 时间轴控制 + 导出
struct PlaybackScreen: View {
    let meta: RecordingMeta
    let store: RecordingStore

    @StateObject private var player = PlaybackPlayer()
    @State private var csvURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            AvatarSceneView(renderer: player.renderer)
                .overlay(alignment: .bottomLeading) {
                    BlendshapePanel(coefficients: player.currentCoefficients, topCount: 5)
                        .padding(10)
                        .scaleEffect(0.9, anchor: .bottomLeading)
                }

            VStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { player.playhead },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(0.01, player.duration)
                )
                HStack {
                    Text(String(format: "%.1fs", player.playhead))
                        .font(.caption.monospacedDigit())
                    Spacer()
                    Button {
                        player.togglePlay()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                    }
                    Spacer()
                    Text(String(format: "%.1fs", player.duration))
                        .font(.caption.monospacedDigit())
                }
            }
            .padding()
        }
        .navigationTitle("回放")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ShareLink(item: store.jsonURL(for: meta)) {
                        Label("导出 JSON", systemImage: "doc.text")
                    }
                    if let csvURL {
                        ShareLink(item: csvURL) {
                            Label("导出 CSV", systemImage: "tablecells")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            player.load(store.loadFrames(for: meta))
            csvURL = store.exportCSV(for: meta)
        }
        .onDisappear {
            player.pause()
        }
    }
}

final class PlaybackPlayer: ObservableObject {
    @Published var playhead: Double = 0
    @Published var isPlaying = false
    @Published var currentCoefficients: [Float] = .init(repeating: 0, count: BlendShapeKey.count)

    let renderer = AvatarRenderer()
    private var frames: [StoredFrame] = []
    private var timer: Timer?

    var duration: Double { frames.last?.t ?? 0 }

    func load(_ frames: [StoredFrame]) {
        self.frames = frames
        seek(to: 0)
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard !frames.isEmpty else { return }
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func seek(to t: Double) {
        playhead = min(max(0, t), duration)
        apply()
    }

    private func tick() {
        playhead += 1.0 / 30.0
        if playhead > duration { playhead = 0 }  // 循环播放
        apply()
    }

    private func apply() {
        guard !frames.isEmpty else { return }
        // 找到当前播放头对应的帧（帧按 t 升序）
        var index = frames.firstIndex { $0.t >= playhead } ?? frames.count - 1
        if index > 0 { index -= 1 }
        let frame = frames[index]
        currentCoefficients = frame.c
        let head = frame.h.count >= 3 ? SIMD3<Float>(frame.h[0], frame.h[1], frame.h[2]) : .zero
        renderer.update(coefficients: frame.c, head: head, landmarks: nil)
    }
}
