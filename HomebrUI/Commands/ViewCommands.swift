import SwiftUI

struct ViewCommands: Commands {
  var body: some Commands {
    CommandGroup(after: .sidebar) {
      ViewCommandsContent()
    }
  }
}

private struct ViewCommandsContent: View {
  @FocusedBinding(\.selectedSidebarItem) var selectedSidebarItem

  var body: some View {
    Section {
      Button("Installed") {
        selectedSidebarItem = .installed
      }
      .keyboardShortcut("1", modifiers: .command)
      Button("Search") {
        selectedSidebarItem = .search
      }
      .keyboardShortcut("2", modifiers: .command)
    }
  }
}

private struct SelectedSidebarItemKey: FocusedValueKey {
  typealias Value = Binding<SidebarItem>
}

extension FocusedValues {
  var selectedSidebarItem: Binding<SidebarItem>? {
    get { self[SelectedSidebarItemKey.self] }
    set { self[SelectedSidebarItemKey.self] = newValue }
  }
}
