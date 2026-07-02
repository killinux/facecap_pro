import SwiftUI

/// 情绪识别面板：主导情绪 + 7 类概率条
struct EmotionPanel: View {
    let scores: [EmotionScore]

    private var dominant: EmotionScore? {
        scores.max { $0.probability < $1.probability }
    }

    var body: some View {
        HStack(spacing: 14) {
            if let dominant {
                VStack(spacing: 2) {
                    Text(dominant.emotion.emoji)
                        .font(.system(size: 40))
                    Text(dominant.emotion.label)
                        .font(.caption.bold())
                    Text("\(Int(dominant.probability * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 64)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(scores) { score in
                    VStack(spacing: 3) {
                        ZStack(alignment: .bottom) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule()
                                .fill(score.emotion == dominant?.emotion ? Color.green : Color.cyan.opacity(0.7))
                                .frame(height: max(2, 44 * CGFloat(score.probability)))
                        }
                        .frame(width: 10, height: 44)
                        Text(score.emotion.emoji)
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .padding(12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Blendshape 面板：显示当前激活最强的通道
struct BlendshapePanel: View {
    let coefficients: [Float]
    var topCount = 8

    private var top: [(name: String, value: Float)] {
        zip(BlendShapeKey.allCases, coefficients)
            .sorted { $0.1 > $1.1 }
            .prefix(topCount)
            .map { ($0.0.rawValue, $0.1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(top, id: \.name) { item in
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(width: 130, alignment: .leading)
                        .lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule()
                                .fill(Color.orange)
                                .frame(width: max(2, geo.size.width * CGFloat(item.value)))
                        }
                    }
                    .frame(height: 5)
                    Text(String(format: "%.2f", item.value))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 30)
                }
            }
        }
        .padding(12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
    }
}
