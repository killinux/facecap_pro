import simd
import Foundation

/// 一帧融合后的面部数据
struct FaceFrame {
    /// 主机时间（秒）
    let time: TimeInterval
    /// 52 个 blendshape 系数，顺序 = BlendShapeKey.allCases
    let coefficients: [Float]
    /// 头部姿态（pitch, yaw, roll，弧度）
    let head: SIMD3<Float>
    /// MediaPipe 478 个归一化关键点（仅 MediaPipe 模式下用于叠加显示）
    let landmarks: [SIMD3<Float>]?
    /// 数据来源: "fusion" / "arkit" / "mediapipe"
    let source: String
}

/// 录制文件中的单帧（精简存储）
struct StoredFrame: Codable {
    /// 相对录制起点的时间（秒）
    var t: Double
    /// 52 个系数
    var c: [Float]
    /// [pitch, yaw, roll]
    var h: [Float]
}

struct RecordingMeta: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let duration: Double
    let frameCount: Int
    let mode: String
    let fileName: String
}

struct RecordingFile: Codable {
    let version: Int
    let mode: String
    let createdAt: Date
    let blendshapeNames: [String]
    let frames: [StoredFrame]
}
