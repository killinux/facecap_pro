import SwiftUI

@main
struct FaceCapProApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject private var store: RecordingStore
    @StateObject private var viewModel: CaptureViewModel

    init() {
        let store = RecordingStore()
        _store = StateObject(wrappedValue: store)
        _viewModel = StateObject(wrappedValue: CaptureViewModel(recordingStore: store))
    }

    var body: some View {
        TabView {
            CaptureScreen(viewModel: viewModel)
                .tabItem { Label("捕捉", systemImage: "face.dashed") }
            RecordingsScreen(store: store)
                .tabItem { Label("录制", systemImage: "list.bullet.rectangle") }
            SettingsScreen(fusionAvailable: viewModel.engine.mode == .fusion)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
