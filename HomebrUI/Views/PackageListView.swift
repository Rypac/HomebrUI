import Combine
import SwiftUI

class PackageListViewModel: ObservableObject {
  struct Environment {
    var packages: AnyPublisher<[Package], Never>
    var isRefreshing: AnyPublisher<Bool, Never>
    var uninstall: (Package) -> Void
  }

  @Published private(set) var isRefreshing: Bool = false
  @Published private(set) var packages: [Package] = []

  @Input var query: String = ""

  private let environment: Environment

  init(environment: Environment) {
    self.environment = environment

    environment.isRefreshing
      .receive(on: DispatchQueue.main)
      .assign(to: &$isRefreshing)

    Publishers
      .CombineLatest(environment.packages, $query.removeDuplicates())
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

  func uninstall(package: Package) {
    environment.uninstall(package)
  }
}

extension PackageListViewModel {
  convenience init(repository: PackageRepository) {
    self.init(
      environment: Environment(
        packages: repository.packages,
        isRefreshing: repository.refreshing,
        uninstall: repository.uninstall
      )
    )
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
        .contextMenu {
          Button("Delete") {
            viewModel.uninstall(package: package)
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
