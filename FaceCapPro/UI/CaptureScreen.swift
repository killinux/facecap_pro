import SwiftUI

struct CaptureScreen: View {
    @ObservedObject var viewModel: CaptureViewModel
    @AppStorage("showMesh") private var showMesh = true
    @AppStorage("showEmotionPanel") private var showEmotionPanel = true
    @State private var previewMode: PreviewMode = .camera

    enum PreviewMode: String, CaseIterable {
        case camera = "相机"
        case avatar = "虚拟头像"
    }

    var body: some View {
        ZStack {
            preview
                .ignoresSafeArea()

            VStack(spacing: 10) {
                header
                Picker("预览", selection: $previewMode) {
                    ForEach(PreviewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Spacer()

                if showEmotionPanel {
                    EmotionPanel(scores: viewModel.emotionScores)
                }
                BlendshapePanel(coefficients: viewModel.uiCoefficients)
                recordBar
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .alert("提示", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay {
            if viewModel.permissionDenied {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                    Text("需要摄像头权限才能进行面部捕捉\n请到 设置 > FaceCap Pro 中开启")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                }
                .padding(24)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch previewMode {
        case .camera:
            if let session = viewModel.engine.arSession {
                ARCameraMeshView(session: session, showMesh: showMesh)
            } else if let captureSession = viewModel.engine.captureSession {
                ZStack {
                    CameraPreviewView(session: captureSession)
                    if showMesh {
                        LandmarkOverlay(landmarks: viewModel.landmarks)
                    }
                }
            } else {
                Color.black
            }
        case .avatar:
            AvatarSceneView(renderer: viewModel.avatarRenderer)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.modeBadge)
                    .font(.caption.bold())
                Text(viewModel.sourceLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.55), in: Capsule())

            Spacer()

            Text(String(format: "%.0f fps", viewModel.fps))
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55), in: Capsule())

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showEmotionPanel.toggle()
                }
            } label: {
                Image(systemName: showEmotionPanel ? "theatermasks.fill" : "theatermasks")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.55), in: Capsule())
            }
        }
    }

    private var recordBar: some View {
        HStack(spacing: 16) {
            if viewModel.isRecording {
                Text(timeString(viewModel.recordingElapsed))
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(.red)
            }
            Button {
                viewModel.toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 64, height: 64)
                    RoundedRectangle(cornerRadius: viewModel.isRecording ? 6 : 26)
                        .fill(.red)
                        .frame(width: viewModel.isRecording ? 28 : 52,
                               height: viewModel.isRecording ? 28 : 52)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d.%01d", Int(t) / 60, Int(t) % 60, Int(t * 10) % 10)
    }
}
