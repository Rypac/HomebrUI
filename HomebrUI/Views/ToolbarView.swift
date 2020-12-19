import Combine
import SwiftUI

struct ToolbarView: ToolbarContent {
  let operations: AnyPublisher<[HomebrewOperation], Never>

  @Binding var isInfoPopoverPresented: Bool

  var body: some ToolbarContent {
    ToolbarItem(placement: .navigation) {
      Button(action: toggleSidebar) {
        Label("Toggle Sidebar", systemImage: "sidebar.left")
      }
    }
    ToolbarItem(placement: .status) {
      Button {
        isInfoPopoverPresented.toggle()
      } label: {
        Label("Info", systemImage: "info.circle")
      }
      .popover(isPresented: $isInfoPopoverPresented) {
        OperationInfoView(
          viewModel: OperationInfoViewModel(environment: .init(operations: operations))
        )
      }
      .keyboardShortcut("i", modifiers: .command)
    }
  }
}

private func toggleSidebar() {
  NSApp.keyWindow?.firstResponder?.tryToPerform(
    #selector(NSSplitViewController.toggleSidebar(_:)),
    with: nil
  )
}
