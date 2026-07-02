import ARKit
import AVFoundation
import QuartzCore

/// 双引擎融合核心：
/// - 支持 TrueDepth 的机型：ARKit 深度追踪为主 + MediaPipe 神经网络按权重融合（精度最高）
/// - 其他机型：自动降级为纯 MediaPipe
/// 输出统一经过 One Euro 滤波去抖。
final class FusionEngine {
    enum Mode: String {
        case fusion       // ARKit + MediaPipe
        case mediaPipeOnly
    }

    let mode: Mode
    private(set) var mediaPipeAvailable: Bool

    /// 融合结果回调（主线程）
    var onFrame: ((FaceFrame) -> Void)?
    /// 错误提示回调（主线程）
    var onError: ((String) -> Void)?

    private let arTracker: ARKitFaceTracker?
    private let cameraFeed: CameraFeed?
    private let mpTracker: MediaPipeFaceTracker?
    private let queue = DispatchQueue(label: "com.facecappro.fusion")

    private var filters = BlendShapeKey.allCases.map { _ in OneEuroFilter() }
    private var latestMP: MediaPipeFaceTracker.Output?
    private var latestMPHostTime: TimeInterval = 0
    private var lastMPFeedMs = 0
    private var running = false

    var arSession: ARSession? { arTracker?.session }
    var captureSession: AVCaptureSession? { cameraFeed?.session }

    init() {
        let mp = MediaPipeFaceTracker()
        mpTracker = mp.isAvailable ? mp : nil
        mediaPipeAvailable = mp.isAvailable

        if ARFaceTrackingConfiguration.isSupported {
            mode = .fusion
            arTracker = ARKitFaceTracker()
            cameraFeed = nil
        } else {
            mode = .mediaPipeOnly
            arTracker = nil
            cameraFeed = CameraFeed()
        }
        wire()
    }

    private func wire() {
        arTracker?.onCameraFrame = { [weak self] buffer, ms in
            guard let self, let mp = self.mpTracker else { return }
            // MediaPipe 约 30Hz 即可，无需吃满 ARKit 的 60fps
            if ms - self.lastMPFeedMs >= 33 {
                self.lastMPFeedMs = ms
                // ARKit 的 capturedImage 为横向传感器方向，竖屏使用需标记 .right
                mp.detect(pixelBuffer: buffer, orientation: .right, timestampMs: ms)
            }
        }
        arTracker?.onFaceUpdate = { [weak self] coeffs, transform, time in
            self?.queue.async {
                self?.fuse(arCoeffs: coeffs, transform: transform, time: time)
            }
        }
        cameraFeed?.onFrame = { [weak self] buffer, ms in
            self?.mpTracker?.detect(pixelBuffer: buffer, orientation: .up, timestampMs: ms)
        }
        mpTracker?.onResult = { [weak self] output in
            guard let self else { return }
            self.queue.async {
                self.latestMP = output
                self.latestMPHostTime = CACurrentMediaTime()
                if self.mode == .mediaPipeOnly {
                    self.emitFromMediaPipe(output)
                }
            }
        }
    }

    func start() {
        guard !running else { return }
        running = true
        queue.async { self.filters.forEach { $0.reset() } }

        switch mode {
        case .fusion:
            arTracker?.start()
            if mpTracker == nil {
                DispatchQueue.main.async {
                    self.onError?("未找到 face_landmarker.task 模型，已降级为纯 ARKit 模式（请运行 scripts/setup.sh 下载模型后重新构建）")
                }
            }
        case .mediaPipeOnly:
            guard mpTracker != nil else {
                running = false
                DispatchQueue.main.async {
                    self.onError?("此设备不支持 ARKit 面部追踪，且 MediaPipe 模型缺失，无法捕捉")
                }
                return
            }
            cameraFeed?.start()
        }
    }

    func stop() {
        guard running else { return }
        running = false
        arTracker?.stop()
        cameraFeed?.stop()
    }

    // MARK: - 融合

    private func fuse(arCoeffs: [BlendShapeKey: Float], transform: simd_float4x4, time: TimeInterval) {
        let wAR = AppSettings.arkitWeight
        // MediaPipe 结果 150ms 内视为新鲜，否则退回纯 ARKit
        let mpFresh: MediaPipeFaceTracker.Output? = {
            guard let mp = latestMP, CACurrentMediaTime() - latestMPHostTime < 0.15 else { return nil }
            return mp
        }()

        var out = [Float](repeating: 0, count: BlendShapeKey.count)
        for (i, key) in BlendShapeKey.allCases.enumerated() {
            let a = arCoeffs[key] ?? 0
            if key == .tongueOut {
                out[i] = a  // MediaPipe 无 tongueOut 通道
            } else if let m = mpFresh?.coefficients[key] {
                out[i] = wAR * a + (1 - wAR) * m
            } else {
                out[i] = a
            }
        }
        smooth(&out, time: time)

        let frame = FaceFrame(
            time: time,
            coefficients: out,
            head: Self.euler(from: transform),
            landmarks: nil,
            source: mpFresh != nil ? "fusion" : "arkit"
        )
        DispatchQueue.main.async { self.onFrame?(frame) }
    }

    private func emitFromMediaPipe(_ output: MediaPipeFaceTracker.Output) {
        let time = Double(output.timestampMs) / 1000.0
        var out = [Float](repeating: 0, count: BlendShapeKey.count)
        for (i, key) in BlendShapeKey.allCases.enumerated() {
            out[i] = output.coefficients[key] ?? 0
        }
        smooth(&out, time: time)

        let frame = FaceFrame(
            time: time,
            coefficients: out,
            head: Self.headPose(fromLandmarks: output.landmarks),
            landmarks: output.landmarks,
            source: "mediapipe"
        )
        DispatchQueue.main.async { self.onFrame?(frame) }
    }

    private func smooth(_ values: inout [Float], time: TimeInterval) {
        let strength = AppSettings.smoothing
        guard strength > 0.02 else { return }
        // 强度越大截止频率越低（平滑越强）：0 → 4Hz（几乎不滤），1 → 0.7Hz
        let minCutoff = 4.0 - 3.3 * strength
        for i in values.indices {
            filters[i].minCutoff = minCutoff
            values[i] = filters[i].filter(values[i], at: time)
        }
    }

    // MARK: - 头部姿态

    static func euler(from m: simd_float4x4) -> SIMD3<Float> {
        let rot = simd_float3x3(
            SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z),
            SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
            SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
        )
        let q = simd_quatf(rot)
        let x = q.imag.x, y = q.imag.y, z = q.imag.z, w = q.real
        let pitch = atan2(2 * (w * x + y * z), 1 - 2 * (x * x + y * y))
        let yaw = asin(max(-1, min(1, 2 * (w * y - z * x))))
        let roll = atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z))
        return SIMD3(pitch, yaw, roll)
    }

    /// 无 ARKit 时用 MediaPipe 关键点几何估算头部姿态（粗略但够预览用）
    static func headPose(fromLandmarks lm: [SIMD3<Float>]) -> SIMD3<Float> {
        guard lm.count > 454 else { return .zero }
        let leftEye = lm[33]      // 左眼外角
        let rightEye = lm[263]    // 右眼外角
        let nose = lm[1]          // 鼻尖
        let forehead = lm[10]     // 额头
        let chin = lm[152]        // 下巴
        let leftSide = lm[234]    // 左脸边缘
        let rightSide = lm[454]   // 右脸边缘

        let roll = atan2(rightEye.y - leftEye.y, rightEye.x - leftEye.x)
        let faceHalfWidth = max(0.001, (rightSide.x - leftSide.x) / 2)
        let yaw = atan2(nose.x - (leftSide.x + rightSide.x) / 2, faceHalfWidth)
        let faceHalfHeight = max(0.001, (chin.y - forehead.y) / 2)
        let pitch = atan2(nose.y - (forehead.y + chin.y) / 2, faceHalfHeight)
        return SIMD3(pitch, yaw, -roll)
    }
}
