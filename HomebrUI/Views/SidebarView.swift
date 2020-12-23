import SwiftUI

struct SidebarView: View {
  private let installedViewModel: InstalledPackagesViewModel
  private let searchViewModel: SearchPackagesViewModel

  @State private var selectedSidebarItem: SidebarItem? = .installed

  init(repository: PackageRepository) {
    installedViewModel = InstalledPackagesViewModel(repository: repository)
    searchViewModel = SearchPackagesViewModel(repository: repository)
  }

  var body: some View {
    NavigationView {
      List(selection: $selectedSidebarItem) {
        NavigationLink(destination: InstalledPackagesView(viewModel: installedViewModel)) {
          Label("Installed", systemImage: "shippingbox")
        }
        .tag(SidebarItem.installed)
        NavigationLink(destination: SearchPackagesView(viewModel: searchViewModel)) {
          Label("Search", systemImage: "magnifyingglass")
        }
        .tag(SidebarItem.search)
      }
      .listStyle(SidebarListStyle())
      .navigationTitle("HomebrUI")
      .frame(minWidth: 200, maxWidth: 300)

      PackageListPlaceholderView()
      PackageDetailPlaceholderView()
    }
    .focusedValue(
      \.selectedSidebarItem,
      $selectedSidebarItem.nonOptional(withDefault: .installed)
    )
  }
}

typealias PackageListPlaceholderView = EmptyView

enum SidebarItem {
  case installed
  case search
}
