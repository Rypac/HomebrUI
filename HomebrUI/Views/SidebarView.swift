import SwiftUI

struct SidebarView: View {
  let repository: PackageRepository

  @State private var selected: SidebarItem? = .installed

  var body: some View {
    NavigationView {
      List(selection: $selected) {
        Group {
          NavigationLink(
            destination: InstalledPackagesView(
              viewModel: InstalledPackagesViewModel(repository: repository)
            )
          ) {
            Label("Installed", systemImage: "shippingbox")
          }
          .tag(SidebarItem.installed)
          NavigationLink(destination: EmptyView()) {
            Label("Search", systemImage: "magnifyingglass")
          }
          .tag(SidebarItem.search)
        }
      }
      .listStyle(SidebarListStyle())
      .navigationTitle("HomebrUI")
      .frame(minWidth: 200, maxWidth: 300)

      PackageListContainer()
      PackageDetailContainer()
    }
  }
}

typealias PackageListContainer = EmptyView
typealias PackageDetailContainer = EmptyView

enum SidebarItem {
  case installed
  case search
}
