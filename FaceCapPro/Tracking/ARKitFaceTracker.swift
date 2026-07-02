import ARKit

/// ARKit TrueDepth 面部追踪：输出 52 个 blendshape 系数 + 头部姿态，
/// 同时把相机帧转发给 MediaPipe 做融合。
final class ARKitFaceTracker: NSObject, ARSessionDelegate {
    let session = ARSession()

    /// (相机帧, 时间戳毫秒) —— 用于喂给 MediaPipe
    var onCameraFrame: ((CVPixelBuffer, Int) -> Void)?
    /// (blendshape 系数, 面部 transform, 时间戳秒)
    var onFaceUpdate: (([BlendShapeKey: Float], simd_float4x4, TimeInterval) -> Void)?
    /// 是否追踪到人脸
    var onTrackingStateChange: ((Bool) -> Void)?

    private static let locationMap: [ARFaceAnchor.BlendShapeLocation: BlendShapeKey] = {
        var map = [ARFaceAnchor.BlendShapeLocation: BlendShapeKey]()
        for key in BlendShapeKey.allCases { map[key.arKitLocation] = key }
        return map
    }()

    private var wasTracking = false

    override init() {
        super.init()
        session.delegate = self
    }

    func start() {
        let config = ARFaceTrackingConfiguration()
        config.maximumNumberOfTrackedFaces = 1
        config.isLightEstimationEnabled = true
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session.pause()
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        onCameraFrame?(frame.capturedImage, Int(frame.timestamp * 1000))

        let face = frame.anchors.compactMap { $0 as? ARFaceAnchor }.first
        let tracking = face?.isTracked ?? false
        if tracking != wasTracking {
            wasTracking = tracking
            onTrackingStateChange?(tracking)
        }
        guard let face, face.isTracked else { return }

        var coeffs = [BlendShapeKey: Float](minimumCapacity: BlendShapeKey.count)
        for (location, value) in face.blendShapes {
            if let key = Self.locationMap[location] {
                coeffs[key] = value.floatValue
            }
        }
        onFaceUpdate?(coeffs, face.transform, frame.timestamp)
    }
}
