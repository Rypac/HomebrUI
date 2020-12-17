import SwiftUI

@main
struct HomebrUIApp: App {
  private let repository = PackageRepository()
  @State private var isPopoverPresented: Bool = false

  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup  {
      SidebarView(repository: repository)
        .toolbar {
          Button {
            isPopoverPresented.toggle()
          } label: {
            Label("Info", systemImage: "info.circle")
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
        .frame(minHeight: 400, idealHeight: 700)
    }
    .commands {
      AppCommands(repository: repository)
    }
  }
}
