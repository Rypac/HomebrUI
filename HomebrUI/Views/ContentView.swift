import SwiftUI

struct ContentView: View {
  let packageRepository: PackageRepository
  let operationRepository: OperationRepository

  @State private var isInfoPopoverPresented: Bool = false

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    SidebarView(repository: packageRepository)
      .toolbar {
        ToolbarView(
          operations: operationRepository.operations,
          isInfoPopoverPresented: $isInfoPopoverPresented
        )
      }
      .onChange(of: scenePhase) { newScenePhase in
        if newScenePhase == .active {
          packageRepository.refresh()
        }
      }
  }
}
