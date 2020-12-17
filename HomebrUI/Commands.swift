import SwiftUI

struct AppCommands: Commands {
  let repository: PackageRepository

  var body: some Commands {
    SidebarCommands()
    CommandMenu("Packages") {
      PackageCommands(repository: repository)
    }
  }
}

private struct PackageCommands: View {
  let repository: PackageRepository

  @FocusedBinding(\.selectedPackage) var selectedPackage

  var body: some View {
    Section {
      Button("Refresh") {
        repository.refresh()
      }
      .keyboardShortcut("r", modifiers: .command)
      Button("Update") {
        // TODO: Implement update
      }
      .keyboardShortcut("u", modifiers: .command)
      .disabled(true)
    }
    Section {
      Button("Uninstall") {
        if let package = selectedPackage {
          repository.uninstall(package)
        }
      }
      .keyboardShortcut("⌫", modifiers: [.command])
      .disabled(selectedPackage == nil)
    }
  }
}

private struct SelectedPackageKey: FocusedValueKey {
  typealias Value = Binding<Package>
}

extension FocusedValues {
  var selectedPackage: Binding<Package>? {
    get { self[SelectedPackageKey.self] }
    set { self[SelectedPackageKey.self] = newValue }
  }
}
