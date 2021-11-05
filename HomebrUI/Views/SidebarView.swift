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
        NavigationLink {
          InstalledPackagesView(viewModel: installedViewModel)
        } label: {
          Label("Installed", systemImage: "shippingbox")
        }
        .tag(SidebarItem.installed)
        NavigationLink {
          SearchPackagesView(viewModel: searchViewModel)
        } label: {
          Label("Search", systemImage: "magnifyingglass")
        }
        .tag(SidebarItem.search)
      }
      .listStyle(.sidebar)
      .frame(minWidth: 200, maxWidth: 300)

      PackageListPlaceholderView()
        .frame(minWidth: 250, maxWidth: 300)
      PackageDetailPlaceholderView()
    }
    .navigationTitle("HomebrUI")
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
