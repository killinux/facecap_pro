import SceneKit
import ARKit

/// 3D 头像渲染器：用融合后的 blendshape 系数驱动 ARKit 面部网格。
/// 设备不支持 ARFaceGeometry 时，降级为 MediaPipe 关键点点云。
final class AvatarRenderer {
    let scnView = SCNView()

    private var faceGeometry: ARSCNFaceGeometry?
    private let faceNode = SCNNode()
    private let pointsNode = SCNNode()
    private var geometryFailed = false

    init() {
        let scene = SCNScene()
        scene.background.contents = UIColor(white: 0.08, alpha: 1)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.01
        cameraNode.position = SCNVector3(0, 0, 0.35)
        scene.rootNode.addChildNode(cameraNode)

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 900
        keyLight.eulerAngles = SCNVector3(-0.3, 0.25, 0)
        scene.rootNode.addChildNode(keyLight)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        scene.rootNode.addChildNode(ambient)

        if let device = MTLCreateSystemDefaultDevice(),
           let geometry = ARSCNFaceGeometry(device: device, fillMesh: true) {
            let material = geometry.firstMaterial
            material?.lightingModel = .physicallyBased
            material?.diffuse.contents = UIColor(red: 0.80, green: 0.73, blue: 0.68, alpha: 1)
            material?.roughness.contents = 0.65
            material?.metalness.contents = 0.0
            faceGeometry = geometry
            faceNode.geometry = geometry
        }
        scene.rootNode.addChildNode(faceNode)
        scene.rootNode.addChildNode(pointsNode)

        scnView.scene = scene
        scnView.antialiasingMode = .multisampling4X
        scnView.rendersContinuously = true
        scnView.allowsCameraControl = true
        scnView.backgroundColor = UIColor(white: 0.08, alpha: 1)
    }

    /// 主线程调用
    func update(coefficients: [Float], head: SIMD3<Float>, landmarks: [SIMD3<Float>]?) {
        if let faceGeometry, !geometryFailed {
            var dict = [ARFaceAnchor.BlendShapeLocation: NSNumber](minimumCapacity: BlendShapeKey.count)
            for (i, key) in BlendShapeKey.allCases.enumerated() {
                dict[key.arKitLocation] = NSNumber(value: coefficients[i])
            }
            if let geo = ARFaceGeometry(blendShapes: dict) {
                faceGeometry.update(from: geo)
                faceNode.isHidden = false
                pointsNode.isHidden = true
                faceNode.eulerAngles = SCNVector3(head.x, head.y, head.z)
                return
            }
            geometryFailed = true  // 该设备无法从 blendshapes 生成网格，改用点云
        }
        if let landmarks, !landmarks.isEmpty {
            faceNode.isHidden = true
            pointsNode.isHidden = false
            pointsNode.geometry = Self.pointCloud(from: landmarks)
        }
    }

    private static func pointCloud(from landmarks: [SIMD3<Float>]) -> SCNGeometry {
        // 归一化坐标 → 以原点为中心的近似真实尺寸（米），y 轴翻转
        let vertices = landmarks.map {
            SCNVector3((0.5 - $0.x) * 0.16, (0.5 - $0.y) * 0.22, -$0.z * 0.16)
        }
        let source = SCNGeometrySource(vertices: vertices)
        let indices = (0..<Int32(vertices.count)).map { $0 }
        let element = SCNGeometryElement(indices: indices, primitiveType: .point)
        element.pointSize = 3
        element.minimumPointScreenSpaceRadius = 1.5
        element.maximumPointScreenSpaceRadius = 3
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.emission.contents = UIColor(red: 0.3, green: 0.9, blue: 0.6, alpha: 1)
        geometry.materials = [material]
        return geometry
    }
}
