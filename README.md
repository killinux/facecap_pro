# FaceCap Pro

仿 [FaceCap](https://apps.apple.com/us/app/face-cap-motion-capture/id1373155478) 的 iOS 面部动作捕捉 + 表情识别应用，采用 **ARKit（TrueDepth 深度传感器）+ Google MediaPipe Face Landmarker（478 关键点神经网络）双引擎融合**，追求消费级设备上可达到的最高表情捕捉精度。

## 功能

- **实时面捕**：52 个 ARKit 标准 blendshape 系数 + 头部姿态（60fps）
- **双引擎融合**：TrueDepth 机型上 ARKit 深度追踪与 MediaPipe 神经网络按可调权重融合；无 TrueDepth 的机型自动降级为纯 MediaPipe（任何前置摄像头都能用）
- **One Euro 滤波防抖**：静止稳、快动不拖影，强度可调
- **3D 虚拟头像**：用融合系数实时驱动面部网格（可旋转查看），相机画面可叠加线框网格 / 关键点
- **情绪识别**：基于 FACS 动作单元（AU）组合的 7 类情绪分类（中性/开心/悲伤/惊讶/愤怒/厌恶/恐惧），带时间平滑，可解释
- **录制 / 回放 / 导出**：录制 blendshape 动画，3D 回放，导出 JSON / CSV（可导入 Blender / Unity / Unreal 驱动 ARKit 标准角色）

## 技术选型（为什么这样最精准）

| 方案 | 精度 | 限制 |
|---|---|---|
| ARKit TrueDepth | 深度传感器级，消费端金标准（Live Link Face、FaceCap 均用它） | 仅 Face ID 机型；精度上限由苹果决定 |
| MediaPipe Face Landmarker | 纯 RGB 最强开源方案，478 个 3D 关键点 + 52 blendshapes | 单目视觉，存在噪声与时间抖动 |
| 学术 SOTA（EMOCA/SMIRK 等） | 离线重建精度最高 | 无法在手机上实时运行 |

本项目取前两者融合：ARKit 提供深度级稳定基准，MediaPipe 提供独立的神经网络估计做加权校验，再经 One Euro 滤波，兼顾精度、稳定性与机型覆盖。情绪分类建立在融合后的 blendshape 之上（深度传感器数据不受光照/肤色影响），映射规则来自 Ekman 七类基本情绪的标准 AU 组合。

## 构建（需要 Mac + Xcode 15+）

```bash
git clone git@github.com:killinux/facecap_pro.git
cd facecap_pro
bash scripts/setup.sh     # 自动安装 xcodegen/cocoapods、下载 MediaPipe 模型、生成工程
open FaceCapPro.xcworkspace
```

然后在 Xcode 中：
1. Signing & Capabilities 里选择你的开发者 Team
2. 连接 iPhone 真机运行（**MediaPipe 不支持模拟器，且需要摄像头，必须真机**）

> 如果 setup.sh 因 Windows 换行符报错，先执行：`sed -i '' $'s/\r$//' scripts/setup.sh`

### 手动步骤（等价于 setup.sh）

```bash
brew install xcodegen cocoapods
mkdir -p FaceCapPro/Resources
curl -L -o FaceCapPro/Resources/face_landmarker.task \
  https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task
xcodegen generate
pod install
```

## 工程结构

```
FaceCapPro/
├── App/            应用入口、TabView
├── Core/           52 通道定义、数据模型、One Euro 滤波、设置
├── Tracking/       ARKitFaceTracker / MediaPipeFaceTracker / CameraFeed / FusionEngine（融合核心）
├── Emotion/        FACS 动作单元 → 7 类情绪分类器
├── Avatar/         SceneKit 3D 头像渲染、相机预览与网格叠加
├── Recording/      录制存储、JSON/CSV 导出
├── ViewModel/      捕捉页状态管理
└── UI/             捕捉 / 录制列表 / 回放 / 设置界面
```

## 导出格式

**JSON**（原始录制文件）：

```json
{
  "version": 1,
  "mode": "fusion",
  "createdAt": "2026-07-02T10:00:00Z",
  "blendshapeNames": ["eyeBlinkLeft", "..."],
  "frames": [{ "t": 0.016, "c": [0.01, "...52 个系数"], "h": [0.02, -0.10, 0.00] }]
}
```

**CSV**：`timestamp, <52 个 blendshape 列>, headPitch, headYaw, headRoll, emotion`

## 已知注意事项

- 融合模式下 MediaPipe 收到的 ARKit 帧按 `.right` 方向处理（竖屏）；若发现 MediaPipe 系数明显异常，检查 `FusionEngine.wire()` 中的 orientation 参数
- MediaPipe 没有 `tongueOut` 通道，该通道始终取 ARKit 值
- 后续可扩展：OSC/UDP 实时串流到 Blender/Unity（FaceCap 的 Live Mode）、FBX 导出
