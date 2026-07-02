import SwiftUI

struct SettingsScreen: View {
    @AppStorage("arkitWeight") private var arkitWeight = 0.6
    @AppStorage("smoothing") private var smoothing = 0.5
    @AppStorage("showMesh") private var showMesh = true

    let fusionAvailable: Bool

    var body: some View {
        NavigationStack {
            Form {
                if fusionAvailable {
                    Section {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("MediaPipe")
                                    .font(.caption)
                                Slider(value: $arkitWeight, in: 0...1)
                                Text("ARKit")
                                    .font(.caption)
                            }
                            Text("ARKit 权重 \(Int(arkitWeight * 100))%（默认 60%。ARKit 来自深度传感器更稳定，MediaPipe 对细微嘴部动作更敏感）")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("融合权重")
                    }
                }

                Section {
                    VStack(alignment: .leading) {
                        Slider(value: $smoothing, in: 0...1)
                        Text("平滑强度 \(Int(smoothing * 100))%（One Euro 滤波：越高越稳但响应稍慢，0 为关闭）")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("防抖")
                }

                Section {
                    Toggle("相机画面叠加面部网格", isOn: $showMesh)
                } header: {
                    Text("显示")
                }

                Section {
                    LabeledContent("捕捉引擎", value: fusionAvailable ? "ARKit + MediaPipe" : "MediaPipe")
                    LabeledContent("Blendshape 通道", value: "52")
                    LabeledContent("情绪识别", value: "FACS 动作单元 · 7 类")
                } header: {
                    Text("关于")
                } footer: {
                    Text("面捕数据可在录制回放页导出为 JSON / CSV，可导入 Blender、Unity、Unreal 等工具驱动 ARKit 标准 blendshape 角色。")
                }
            }
            .navigationTitle("设置")
        }
    }
}
