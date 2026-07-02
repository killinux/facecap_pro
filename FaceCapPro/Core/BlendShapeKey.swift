import ARKit

/// 52 个 ARKit 标准 blendshape 通道。
/// 枚举 rawValue 与 MediaPipe Face Landmarker 输出的 categoryName 完全一致，
/// 因此可直接按名字对齐两套引擎的输出。
enum BlendShapeKey: String, CaseIterable, Codable {
    // 眼部 (14)
    case eyeBlinkLeft, eyeLookDownLeft, eyeLookInLeft, eyeLookOutLeft
    case eyeLookUpLeft, eyeSquintLeft, eyeWideLeft
    case eyeBlinkRight, eyeLookDownRight, eyeLookInRight, eyeLookOutRight
    case eyeLookUpRight, eyeSquintRight, eyeWideRight
    // 下颌 (4)
    case jawForward, jawLeft, jawRight, jawOpen
    // 嘴部 (23)
    case mouthClose, mouthFunnel, mouthPucker, mouthLeft, mouthRight
    case mouthSmileLeft, mouthSmileRight, mouthFrownLeft, mouthFrownRight
    case mouthDimpleLeft, mouthDimpleRight, mouthStretchLeft, mouthStretchRight
    case mouthRollLower, mouthRollUpper, mouthShrugLower, mouthShrugUpper
    case mouthPressLeft, mouthPressRight, mouthLowerDownLeft, mouthLowerDownRight
    case mouthUpperUpLeft, mouthUpperUpRight
    // 眉部 (5)
    case browDownLeft, browDownRight, browInnerUp, browOuterUpLeft, browOuterUpRight
    // 脸颊 (3)
    case cheekPuff, cheekSquintLeft, cheekSquintRight
    // 鼻部 (2)
    case noseSneerLeft, noseSneerRight
    // 舌头 (1)：仅 ARKit 提供，MediaPipe 无此通道
    case tongueOut

    static let count = allCases.count

    private static let indexLookup: [BlendShapeKey: Int] = {
        var map = [BlendShapeKey: Int]()
        for (i, key) in allCases.enumerated() { map[key] = i }
        return map
    }()

    var index: Int { Self.indexLookup[self]! }

    /// 对应的 ARKit BlendShapeLocation（名字一一对应）
    var arKitLocation: ARFaceAnchor.BlendShapeLocation {
        switch self {
        case .eyeBlinkLeft: return .eyeBlinkLeft
        case .eyeLookDownLeft: return .eyeLookDownLeft
        case .eyeLookInLeft: return .eyeLookInLeft
        case .eyeLookOutLeft: return .eyeLookOutLeft
        case .eyeLookUpLeft: return .eyeLookUpLeft
        case .eyeSquintLeft: return .eyeSquintLeft
        case .eyeWideLeft: return .eyeWideLeft
        case .eyeBlinkRight: return .eyeBlinkRight
        case .eyeLookDownRight: return .eyeLookDownRight
        case .eyeLookInRight: return .eyeLookInRight
        case .eyeLookOutRight: return .eyeLookOutRight
        case .eyeLookUpRight: return .eyeLookUpRight
        case .eyeSquintRight: return .eyeSquintRight
        case .eyeWideRight: return .eyeWideRight
        case .jawForward: return .jawForward
        case .jawLeft: return .jawLeft
        case .jawRight: return .jawRight
        case .jawOpen: return .jawOpen
        case .mouthClose: return .mouthClose
        case .mouthFunnel: return .mouthFunnel
        case .mouthPucker: return .mouthPucker
        case .mouthLeft: return .mouthLeft
        case .mouthRight: return .mouthRight
        case .mouthSmileLeft: return .mouthSmileLeft
        case .mouthSmileRight: return .mouthSmileRight
        case .mouthFrownLeft: return .mouthFrownLeft
        case .mouthFrownRight: return .mouthFrownRight
        case .mouthDimpleLeft: return .mouthDimpleLeft
        case .mouthDimpleRight: return .mouthDimpleRight
        case .mouthStretchLeft: return .mouthStretchLeft
        case .mouthStretchRight: return .mouthStretchRight
        case .mouthRollLower: return .mouthRollLower
        case .mouthRollUpper: return .mouthRollUpper
        case .mouthShrugLower: return .mouthShrugLower
        case .mouthShrugUpper: return .mouthShrugUpper
        case .mouthPressLeft: return .mouthPressLeft
        case .mouthPressRight: return .mouthPressRight
        case .mouthLowerDownLeft: return .mouthLowerDownLeft
        case .mouthLowerDownRight: return .mouthLowerDownRight
        case .mouthUpperUpLeft: return .mouthUpperUpLeft
        case .mouthUpperUpRight: return .mouthUpperUpRight
        case .browDownLeft: return .browDownLeft
        case .browDownRight: return .browDownRight
        case .browInnerUp: return .browInnerUp
        case .browOuterUpLeft: return .browOuterUpLeft
        case .browOuterUpRight: return .browOuterUpRight
        case .cheekPuff: return .cheekPuff
        case .cheekSquintLeft: return .cheekSquintLeft
        case .cheekSquintRight: return .cheekSquintRight
        case .noseSneerLeft: return .noseSneerLeft
        case .noseSneerRight: return .noseSneerRight
        case .tongueOut: return .tongueOut
        }
    }
}
