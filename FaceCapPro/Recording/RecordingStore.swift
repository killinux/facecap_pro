import Foundation
import Combine

/// 录制文件管理：保存 / 列表 / 删除 / 导出（JSON 原始文件 + CSV）。仅在主线程使用。
final class RecordingStore: ObservableObject {
    @Published private(set) var recordings: [RecordingMeta] = []

    private let directory: URL
    private let indexURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = docs.appendingPathComponent("Recordings", isDirectory: true)
        indexURL = directory.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        loadIndex()
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let metas = try? Self.decoder().decode([RecordingMeta].self, from: data) else { return }
        recordings = metas.sorted { $0.createdAt > $1.createdAt }
    }

    private func saveIndex() {
        if let data = try? Self.encoder().encode(recordings) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    @discardableResult
    func save(frames: [StoredFrame], mode: String) -> RecordingMeta? {
        guard !frames.isEmpty else { return nil }
        let id = UUID()
        let createdAt = Date()
        let fileName = "rec_\(Int(createdAt.timeIntervalSince1970))_\(id.uuidString.prefix(8)).json"

        let file = RecordingFile(
            version: 1,
            mode: mode,
            createdAt: createdAt,
            blendshapeNames: BlendShapeKey.allCases.map(\.rawValue),
            frames: frames
        )
        guard let data = try? Self.encoder().encode(file) else { return nil }
        do {
            try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        } catch {
            NSLog("[Recording] 保存失败: \(error)")
            return nil
        }

        let meta = RecordingMeta(
            id: id,
            createdAt: createdAt,
            duration: frames.last?.t ?? 0,
            frameCount: frames.count,
            mode: mode,
            fileName: fileName
        )
        recordings.insert(meta, at: 0)
        saveIndex()
        return meta
    }

    func delete(_ meta: RecordingMeta) {
        try? FileManager.default.removeItem(at: jsonURL(for: meta))
        recordings.removeAll { $0.id == meta.id }
        saveIndex()
    }

    func jsonURL(for meta: RecordingMeta) -> URL {
        directory.appendingPathComponent(meta.fileName)
    }

    func loadFrames(for meta: RecordingMeta) -> [StoredFrame] {
        guard let data = try? Data(contentsOf: jsonURL(for: meta)),
              let file = try? Self.decoder().decode(RecordingFile.self, from: data) else { return [] }
        return file.frames
    }

    /// 生成 CSV 并返回临时文件 URL。
    /// 列：时间戳、52 个 blendshape、头部姿态、逐帧重算的情绪标签。
    func exportCSV(for meta: RecordingMeta) -> URL? {
        let frames = loadFrames(for: meta)
        guard !frames.isEmpty else { return nil }

        var csv = "timestamp," + BlendShapeKey.allCases.map(\.rawValue).joined(separator: ",")
            + ",headPitch,headYaw,headRoll,emotion\n"

        let classifier = EmotionClassifier()
        for frame in frames {
            let coeffs = frame.c.map { String(format: "%.4f", $0) }.joined(separator: ",")
            let head = frame.h.map { String(format: "%.4f", $0) }.joined(separator: ",")
            let emotion = classifier.classify(frame.c)
                .max { $0.probability < $1.probability }?.emotion.rawValue ?? "neutral"
            csv += String(format: "%.4f", frame.t) + "," + coeffs + "," + head + "," + emotion + "\n"
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(meta.fileName.replacingOccurrences(of: ".json", with: ".csv"))
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
