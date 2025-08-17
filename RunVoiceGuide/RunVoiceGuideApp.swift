import SwiftUI

@main
struct RunVoiceGuideApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var storage = StorageService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()  // 直接 Running を起点に
        }
        .onChange(of: scenePhase) { phase in
            if phase == .inactive || phase == .background {
                print("[App] scenePhase=\(phase) -> save()")
                storage.save()
            }
        }
    }
}
