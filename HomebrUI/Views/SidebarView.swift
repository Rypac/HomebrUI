import SwiftUI

struct SidebarView: View {
  let repository: PackageRepository

  var body: some View {
    NavigationView {
      List {
        Group {
          NavigationLink(
            destination: PackageListView(
              viewModel: PackageListViewModel(repository: repository)
            )
          ) {
            Label("Installed", systemImage: "shippingbox")
          }
          NavigationLink(destination: EmptyView()) {
            Label("Search", systemImage: "magnifyingglass")
          }
        }
        Spacer()
        Divider()
        NavigationLink(destination: EmptyView()) {
          Label("Settings", systemImage: "gear")
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
