import Combine
import SwiftUI

struct ToolbarView: ToolbarContent {
  private let operationViewModel: OperationInfoViewModel

  @Binding var isInfoPopoverPresented: Bool

  init(operations: some Publisher<[HomebrewOperation], Never>, isInfoPopoverPresented: Binding<Bool>) {
    self._isInfoPopoverPresented = isInfoPopoverPresented
    self.operationViewModel = OperationInfoViewModel(operations: operations)
  }

  var body: some ToolbarContent {
    ToolbarItem(placement: .navigation) {
      Button(action: toggleSidebar) {
        Label("Toggle Sidebar", systemImage: "sidebar.left")
      }
      .help("Hide or show the Sidebar")
    }
    ToolbarItem(placement: .status) {
      Button {
        isInfoPopoverPresented.toggle()
      } label: {
        Label("Info", systemImage: "info.circle")
      }
      .popover(isPresented: $isInfoPopoverPresented) {
        OperationInfoView(viewModel: operationViewModel)
      }
      .keyboardShortcut("i", modifiers: .command)
      .help("Show or hide Homebrew operation info")
    }
  }
}

private func toggleSidebar() {
  NSApp.keyWindow?.firstResponder?.tryToPerform(
    #selector(NSSplitViewController.toggleSidebar(_:)),
    with: nil
  )
}
