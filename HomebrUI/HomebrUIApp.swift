import SwiftUI

@main
struct HomebrUIApp: App {
  private let repository = PackageRepository()
  @State private var isPopoverPresented: Bool = false

  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup  {
      NavigationView {
        PackageListView(viewModel: PackageListViewModel(repository: repository))
          .frame(minWidth: 200)
          .listStyle(SidebarListStyle())
      }
      .toolbar {
        Button("Info") {
          isPopoverPresented.toggle()
        }
        .popover(isPresented: $isPopoverPresented) {
          OperationInfoView(viewModel: OperationInfoViewModel(repository: repository))
        }
      }
      .onChange(of: scenePhase) { newScenePhase in
        if newScenePhase == .active {
          repository.refresh()
        }
      }
    }
    .commands {
      AppCommands(repository: repository)
    }
  }
}
