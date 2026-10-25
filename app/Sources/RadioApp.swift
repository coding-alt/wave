import SwiftUI

@main
struct RadioApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("小旋风收音机") {
            RootView(model: model)
                .frame(minWidth: 920, minHeight: 600)
                .task { await model.start() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1140, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SidebarView(model: model)
                ContentView(model: model)
            }
            PlayerBar(model: model)
        }
    }
}
