import SwiftUI

@main
struct HomebrUIApp: App {
  private let repository = PackageRepository()

  @State private var isInfoPopoverPresented: Bool = false

  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup  {
      SidebarView(repository: repository)
        .toolbar {
          ToolbarView(
            repository: repository,
            isInfoPopoverPresented: $isInfoPopoverPresented
          )
        }
        .onChange(of: scenePhase) { newScenePhase in
          if newScenePhase == .active {
            repository.refresh()
          }
        }
        .frame(minHeight: 400, idealHeight: 700)
    }
    .commands {
      AppCommands(repository: repository)
    }
  }
}
