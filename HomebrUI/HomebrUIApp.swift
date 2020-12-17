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
          ToolbarItem(placement: .navigation) {
            Button(action: toggleSidebar) {
              Label("Toggle Sidebar", systemImage: "sidebar.left")
            }
          }
          ToolbarItem {
            Button {
              isPopoverPresented.toggle()
            } label: {
              Label("Info", systemImage: "info.circle")
            }
            .popover(isPresented: $isPopoverPresented) {
              OperationInfoView(viewModel: OperationInfoViewModel(repository: repository))
            }
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

private func toggleSidebar() {
  NSApp.keyWindow?.firstResponder?.tryToPerform(
    #selector(NSSplitViewController.toggleSidebar(_:)),
    with: nil
  )
}
