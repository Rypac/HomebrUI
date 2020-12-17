import SwiftUI

struct ToolbarView: ToolbarContent {
  let repository: PackageRepository

  @Binding var isInfoPopoverPresented: Bool

  var body: some ToolbarContent {
    ToolbarItem(placement: .navigation) {
      Button(action: toggleSidebar) {
        Label("Toggle Sidebar", systemImage: "sidebar.left")
      }
    }
    ToolbarItem {
      Button {
        isInfoPopoverPresented.toggle()
      } label: {
        Label("Info", systemImage: "info.circle")
      }
      .popover(isPresented: $isInfoPopoverPresented) {
        OperationInfoView(viewModel: OperationInfoViewModel(repository: repository))
      }
    }
  }
}

private func toggleSidebar() {
  NSApp.keyWindow?.firstResponder?.tryToPerform(
    #selector(NSSplitViewController.toggleSidebar(_:)),
    with: nil
  )
}
