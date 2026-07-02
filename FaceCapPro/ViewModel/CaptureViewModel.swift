import Foundation
import AVFoundation
import Combine

/// 捕捉页状态。FusionEngine 的回调已切换到主线程，所有成员均只在主线程访问。
final class CaptureViewModel: ObservableObject {
    // UI 状态（约 15Hz 节流刷新，头像渲染仍为全帧率）
    @Published var uiCoefficients: [Float] = .init(repeating: 0, count: BlendShapeKey.count)
    @Published var emotionScores: [EmotionScore] = []
    @Published var landmarks: [SIMD3<Float>] = []
    @Published var isRecording = false
    @Published var recordingElapsed: TimeInterval = 0
    @Published var fps: Double = 0
    @Published var sourceLabel = ""
    @Published var permissionDenied = false
    @Published var errorMessage: String?

    let engine = FusionEngine()
    let avatarRenderer = AvatarRenderer()
    let recordingStore: RecordingStore

    private let emotionClassifier = EmotionClassifier()
    private var lastUIUpdate: TimeInterval = 0
    private var recordingStart: TimeInterval?
    private var recordedFrames: [StoredFrame] = []
    private var fpsCounter = 0
    private var fpsWindowStart: TimeInterval = 0

    var modeBadge: String {
        switch engine.mode {
        case .fusion:
            return engine.mediaPipeAvailable ? "ARKit + MediaPipe 融合" : "ARKit"
        case .mediaPipeOnly:
            return "MediaPipe"
        }
    }

    init(recordingStore: RecordingStore) {
        self.recordingStore = recordingStore
        engine.onFrame = { [weak self] frame in
            self?.handle(frame)
        }
        engine.onError = { [weak self] message in
            self?.errorMessage = message
        }
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            engine.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.engine.start()
                    } else {
                        self.permissionDenied = true
                    }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        if isRecording { stopRecording() }
        engine.stop()
    }

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recordedFrames = []
        recordingStart = nil  // 以第一帧为 0 点
        recordingElapsed = 0
        isRecording = true
    }

    private func stopRecording() {
        isRecording = false
        let frames = recordedFrames
        recordedFrames = []
        recordingStore.save(frames: frames, mode: engine.mode.rawValue)
    }

    private func handle(_ frame: FaceFrame) {
        // 头像全帧率驱动
        avatarRenderer.update(coefficients: frame.coefficients, head: frame.head, landmarks: frame.landmarks)

        // 录制
        if isRecording {
            if recordingStart == nil { recordingStart = frame.time }
            let t = frame.time - (recordingStart ?? frame.time)
            recordedFrames.append(StoredFrame(
                t: t,
                c: frame.coefficients,
                h: [frame.head.x, frame.head.y, frame.head.z]
            ))
            recordingElapsed = t
        }

        // FPS 统计
        fpsCounter += 1
        if frame.time - fpsWindowStart >= 1.0 {
            fps = Double(fpsCounter) / (frame.time - fpsWindowStart)
            fpsCounter = 0
            fpsWindowStart = frame.time
        }

        // UI 面板 15Hz 节流
        guard frame.time - lastUIUpdate >= 1.0 / 15.0 else { return }
        lastUIUpdate = frame.time
        uiCoefficients = frame.coefficients
        emotionScores = emotionClassifier.classify(frame.coefficients)
        if let lm = frame.landmarks {
            landmarks = lm
        }
        switch frame.source {
        case "fusion": sourceLabel = "融合中"
        case "arkit": sourceLabel = "仅 ARKit"
        default: sourceLabel = "MediaPipe"
        }
    }
}
