import SwiftUI
import SceneKit
import ARKit
import AVFoundation

/// 3D 头像视图（SceneKit）
struct AvatarSceneView: UIViewRepresentable {
    let renderer: AvatarRenderer

    func makeUIView(context: Context) -> SCNView { renderer.scnView }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

/// 融合模式下的相机画面：ARSCNView 渲染相机背景 + 实时面部网格叠加
struct ARCameraMeshView: UIViewRepresentable {
    let session: ARSession
    let showMesh: Bool

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = session
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.showMesh = showMesh
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        var showMesh = true

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor,
                  let device = renderer.device,
                  let geometry = ARSCNFaceGeometry(device: device, fillMesh: false) else { return nil }
            geometry.firstMaterial?.fillMode = .lines
            geometry.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.5)
            geometry.firstMaterial?.lightingModel = .constant
            return SCNNode(geometry: geometry)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let face = anchor as? ARFaceAnchor,
                  let geometry = node.geometry as? ARSCNFaceGeometry else { return }
            node.isHidden = !showMesh
            geometry.update(from: face.geometry)
        }
    }
}

/// MediaPipe 模式下的相机预览（AVCaptureVideoPreviewLayer）
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

/// MediaPipe 478 关键点叠加层。
/// 预览层默认镜像（自拍习惯），因此绘制时 x 取反以对齐画面。
struct LandmarkOverlay: View {
    let landmarks: [SIMD3<Float>]
    /// 相机缓冲的宽高比（竖屏 720x1280）
    private let imageAspect: CGFloat = 720.0 / 1280.0

    var body: some View {
        Canvas { context, size in
            guard !landmarks.isEmpty else { return }
            let viewAspect = size.width / size.height
            // resizeAspectFill 的映射
            let drawnW: CGFloat
            let drawnH: CGFloat
            if viewAspect > imageAspect {
                drawnW = size.width
                drawnH = size.width / imageAspect
            } else {
                drawnH = size.height
                drawnW = size.height * imageAspect
            }
            let xOff = (size.width - drawnW) / 2
            let yOff = (size.height - drawnH) / 2

            for p in landmarks {
                let x = xOff + CGFloat(1 - p.x) * drawnW
                let y = yOff + CGFloat(p.y) * drawnH
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                    with: .color(Color(red: 0.3, green: 0.9, blue: 0.6).opacity(0.75))
                )
            }
        }
        .allowsHitTesting(false)
    }
}
