import SwiftUI

struct ContentView: View {
  let packageRepository: PackageRepository
  let operationRepository: OperationRepository

  @State private var isInfoPopoverPresented: Bool = false

  var body: some View {
    SidebarView(repository: packageRepository)
      .toolbar {
        ToolbarView(
          operations: operationRepository.operations,
          isInfoPopoverPresented: $isInfoPopoverPresented
        )
      }
      .task {
        await packageRepository.refresh()
      }
  }
}
