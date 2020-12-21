import SwiftUI

struct SidebarView: View {
  let packageRepository: PackageRepository
  let operationRepository: OperationRepository

  @State private var selectedSidebarItem: SidebarItem? = .installed

  var body: some View {
    NavigationView {
      List(selection: $selectedSidebarItem) {
        NavigationLink(
          destination: InstalledPackagesView(
            viewModel: InstalledPackagesViewModel(
              packageRepository: packageRepository,
              operationRepository: operationRepository
            )
          )
        ) {
          Label("Installed", systemImage: "shippingbox")
        }
        .tag(SidebarItem.installed)
        NavigationLink(
          destination: SearchPackagesView(
            viewModel: SearchPackagesViewModel(
              packageRepository: packageRepository,
              operationRepository: operationRepository
            )
          )
        ) {
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
