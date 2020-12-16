import Combine
import SwiftUI

class PackageListViewModel: ObservableObject {
  @Published private(set) var isRefreshing: Bool = false
  @Published private(set) var packages: [Package] = []

  @Input var query: String = ""

  init(repository: PackageRepository) {
    repository.refreshing
      .receive(on: DispatchQueue.main)
      .assign(to: &$isRefreshing)

    Publishers
      .CombineLatest(repository.packages, $query.removeDuplicates())
      .map { packages, query in
        if query.isEmpty {
          return packages
        }
        return packages.filter { package in
          package.name.localizedCaseInsensitiveContains(query)
        }
      }
      .receive(on: DispatchQueue.main)
      .assign(to: &$packages)
  }
}

struct PackageListView: View {
  @ObservedObject var viewModel: PackageListViewModel

  var body: some View {
    VStack {
      TextField("Filter", text: $viewModel.query)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding([.leading, .trailing], 8)
      List(viewModel.packages) { package in
        NavigationLink(destination: PackageDetailView(package: package)) {
          HStack {
            Text(package.name)
            Spacer()
            Text(package.version)
              .foregroundColor(.secondary)
          }
        }
      }
      if viewModel.isRefreshing {
        Spacer()
        HStack {
          Text("Refreshing")
            .font(.callout)
          Spacer()
          ProgressView()
        }
          .padding()
      }
    }
  }
}
