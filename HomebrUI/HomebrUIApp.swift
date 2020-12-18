import SwiftUI

@main
struct HomebrUIApp: App {
  private let packageRepository: PackageRepository
  private let operationRepository: OperationRepository

  @State private var isInfoPopoverPresented: Bool = false

  @Environment(\.scenePhase) private var scenePhase

  init() {
    let homebrew = Homebrew()
    packageRepository = PackageRepository(homebrew: homebrew)
    operationRepository = OperationRepository(homebrew: homebrew)
  }

  var body: some Scene {
    WindowGroup  {
      SidebarView(repository: packageRepository)
        .toolbar {
          ToolbarView(
            repository: operationRepository,
            isInfoPopoverPresented: $isInfoPopoverPresented
          )
        }
        .onChange(of: scenePhase) { newScenePhase in
          if newScenePhase == .active {
            packageRepository.refresh()
          }
        }
        .frame(minHeight: 400, idealHeight: 700)
    }
    .commands {
      AppCommands(repository: packageRepository)
    }
  }
}
