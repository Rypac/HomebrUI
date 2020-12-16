import SwiftUI

@main
struct HomebrUIApp: App {
  private let repository = PackageRepository()

  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup  {
      NavigationView {
        PackageListView(viewModel: PackageListViewModel(repository: repository))
          .frame(minWidth: 200)
          .listStyle(SidebarListStyle())
      }
      .onChange(of: scenePhase) { newScenePhase in
        if newScenePhase == .active {
          repository.refresh()
        }
      }
    }
  }
}
