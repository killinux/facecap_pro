import Foundation

/// 全局设置（UserDefaults 存取，SettingsScreen 通过 @AppStorage 写同名 key）
enum AppSettings {
    /// 融合模式下 ARKit 的权重（0~1），其余为 MediaPipe
    static var arkitWeight: Float {
        Float(UserDefaults.standard.object(forKey: "arkitWeight") as? Double ?? 0.6)
    }

    /// 平滑强度 0~1（0 = 关闭滤波）
    static var smoothing: Float {
        Float(UserDefaults.standard.object(forKey: "smoothing") as? Double ?? 0.5)
    }

    /// 相机画面上是否叠加面部网格/关键点
    static var showMesh: Bool {
        UserDefaults.standard.object(forKey: "showMesh") as? Bool ?? true
    }
}
