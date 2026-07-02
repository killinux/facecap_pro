import Foundation

enum Emotion: String, CaseIterable, Codable {
    case neutral, happy, sad, surprised, angry, disgusted, fearful

    var label: String {
        switch self {
        case .neutral: return "中性"
        case .happy: return "开心"
        case .sad: return "悲伤"
        case .surprised: return "惊讶"
        case .angry: return "愤怒"
        case .disgusted: return "厌恶"
        case .fearful: return "恐惧"
        }
    }

    var emoji: String {
        switch self {
        case .neutral: return "😐"
        case .happy: return "😄"
        case .sad: return "😢"
        case .surprised: return "😮"
        case .angry: return "😠"
        case .disgusted: return "🤢"
        case .fearful: return "😨"
        }
    }
}

struct EmotionScore: Identifiable {
    let emotion: Emotion
    let probability: Float
    var id: String { emotion.rawValue }
}

/// 基于 FACS（面部动作编码系统）的情绪分类器。
/// 输入为融合后的 52 个 blendshape 系数——在 TrueDepth 机型上来自深度传感器，
/// 不受光照/肤色影响，比纯 RGB 图像分类更稳定；映射规则对应 Ekman 七类基本情绪
/// 的标准动作单元（AU）组合，可解释、无需额外模型。
final class EmotionClassifier {
    /// softmax 温度：越小分布越尖锐
    private let temperature: Float = 0.28
    /// 时间平滑系数（EMA）
    private let emaAlpha: Float = 0.25

    private var smoothed: [Emotion: Float] = [:]

    func classify(_ c: [Float]) -> [EmotionScore] {
        func v(_ key: BlendShapeKey) -> Float { c[key.index] }
        func pair(_ l: BlendShapeKey, _ r: BlendShapeKey) -> Float { (v(l) + v(r)) / 2 }

        let smile = pair(.mouthSmileLeft, .mouthSmileRight)          // AU12
        let frown = pair(.mouthFrownLeft, .mouthFrownRight)          // AU15
        let browDown = pair(.browDownLeft, .browDownRight)           // AU4
        let browOuterUp = pair(.browOuterUpLeft, .browOuterUpRight)  // AU2
        let browInnerUp = v(.browInnerUp)                            // AU1
        let eyeWide = pair(.eyeWideLeft, .eyeWideRight)              // AU5
        let eyeSquint = pair(.eyeSquintLeft, .eyeSquintRight)        // AU7
        let cheekSquint = pair(.cheekSquintLeft, .cheekSquintRight)  // AU6
        let sneer = pair(.noseSneerLeft, .noseSneerRight)            // AU9
        let upperLipUp = pair(.mouthUpperUpLeft, .mouthUpperUpRight) // AU10
        let stretch = pair(.mouthStretchLeft, .mouthStretchRight)    // AU20
        let press = pair(.mouthPressLeft, .mouthPressRight)          // AU24
        let jawOpen = v(.jawOpen)                                    // AU26

        var scores: [Emotion: Float] = [:]
        // 开心：AU6+12
        scores[.happy] = 1.2 * smile + 0.5 * cheekSquint - 0.3 * browDown
        // 悲伤：AU1+15
        scores[.sad] = 1.0 * frown + 0.6 * browInnerUp - 0.5 * eyeWide - 0.8 * smile
        // 惊讶：AU1+2+5+26
        scores[.surprised] = 0.7 * eyeWide + 0.5 * browInnerUp + 0.5 * browOuterUp
            + 0.3 * jawOpen - 0.6 * smile - 0.5 * browDown
        // 愤怒：AU4+7+24
        scores[.angry] = 1.0 * browDown + 0.4 * eyeSquint + 0.3 * press
            + 0.2 * sneer - 0.8 * smile
        // 厌恶：AU9+10
        scores[.disgusted] = 1.0 * sneer + 0.6 * upperLipUp + 0.2 * browDown - 0.6 * smile
        // 恐惧：AU1+2+5+20
        scores[.fearful] = 0.5 * eyeWide + 0.4 * browInnerUp + 0.6 * stretch
            + 0.2 * browOuterUp - 0.8 * smile
        // 中性偏置：所有表情都弱时占主导
        scores[.neutral] = 0.35

        // softmax
        let exps = Emotion.allCases.map { expf(max(0, scores[$0] ?? 0) / temperature) }
        let sum = exps.reduce(0, +)

        // EMA 时间平滑，避免情绪标签跳变
        var result: [EmotionScore] = []
        for (i, emotion) in Emotion.allCases.enumerated() {
            let p = exps[i] / sum
            let s = emaAlpha * p + (1 - emaAlpha) * (smoothed[emotion] ?? p)
            smoothed[emotion] = s
            result.append(EmotionScore(emotion: emotion, probability: s))
        }
        // 归一化平滑后的分布
        let total = result.map(\.probability).reduce(0, +)
        return result.map { EmotionScore(emotion: $0.emotion, probability: $0.probability / total) }
    }

    func reset() {
        smoothed.removeAll()
    }
}
