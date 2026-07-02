import UIKit
import MediaPipeTasksVision

/// Google MediaPipe Face Landmarker（liveStream 模式）：
/// 输出 478 个 3D 关键点 + 52 个 blendshape 系数（神经网络回归，纯 RGB 即可工作）。
final class MediaPipeFaceTracker: NSObject {
    struct Output {
        let coefficients: [BlendShapeKey: Float]
        let landmarks: [SIMD3<Float>]
        let timestampMs: Int
    }

    var onResult: ((Output) -> Void)?

    private var landmarker: FaceLandmarker?
    private var lastTimestampMs = -1

    /// 模型缺失或初始化失败时返回 nil，由 FusionEngine 降级处理
    override init() {
        super.init()
        guard let modelPath = Bundle.main.path(forResource: "face_landmarker", ofType: "task") else {
            NSLog("[MediaPipe] face_landmarker.task 不在 bundle 中，请先运行 scripts/setup.sh 下载模型")
            return
        }
        let options = FaceLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .liveStream
        options.numFaces = 1
        options.outputFaceBlendshapes = true
        options.minFaceDetectionConfidence = 0.5
        options.minFacePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5
        options.faceLandmarkerLiveStreamDelegate = self
        do {
            landmarker = try FaceLandmarker(options: options)
        } catch {
            NSLog("[MediaPipe] FaceLandmarker 初始化失败: \(error)")
        }
    }

    var isAvailable: Bool { landmarker != nil }

    /// 送一帧进行异步检测。时间戳必须单调递增（liveStream 模式要求）。
    func detect(pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation, timestampMs: Int) {
        guard let landmarker, timestampMs > lastTimestampMs else { return }
        lastTimestampMs = timestampMs
        do {
            let image = try MPImage(pixelBuffer: pixelBuffer, orientation: orientation)
            try landmarker.detectAsync(image: image, timestampInMilliseconds: timestampMs)
        } catch {
            NSLog("[MediaPipe] detectAsync 失败: \(error)")
        }
    }
}

extension MediaPipeFaceTracker: FaceLandmarkerLiveStreamDelegate {
    func faceLandmarker(_ faceLandmarker: FaceLandmarker,
                        didFinishDetection result: FaceLandmarkerResult?,
                        timestampInMilliseconds: Int,
                        error: Error?) {
        guard error == nil,
              let result,
              let blendshapes = result.faceBlendshapes.first else { return }

        var coeffs = [BlendShapeKey: Float](minimumCapacity: BlendShapeKey.count)
        for category in blendshapes.categories {
            if let name = category.categoryName, let key = BlendShapeKey(rawValue: name) {
                coeffs[key] = category.score
            }
        }
        let landmarks = result.faceLandmarks.first?.map {
            SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z))
        } ?? []

        onResult?(Output(coefficients: coeffs, landmarks: landmarks, timestampMs: timestampInMilliseconds))
    }
}
