import Combine
import SwiftUI

class PackageListViewModel: ObservableObject {
  enum State: Equatable {
    case loading
    case loaded([Package])
  }

  @Published private(set) var isRefreshing: Bool = false
  @Published private(set) var state: State = .loading
  @Input var query: String = ""

  private let triggerLoad = PassthroughSubject<Bool, Never>()

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
      .map(State.loaded)
      .receive(on: DispatchQueue.main)
      .assign(to: &$state)
  }
}

struct PackageListView: View {
  @ObservedObject var viewModel: PackageListViewModel

  var body: some View {
    VStack {
      switch viewModel.state {
      case .loading:
        EmptyView()
      case .loaded(let packages):
        TextField("Filter", text: $viewModel.query)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding([.leading, .trailing], 8)
        List(packages) { package in
          NavigationLink(destination: PackageDetailView(package: package)) {
            HStack {
              Text(package.name)
              Spacer()
              Text(package.version)
                .foregroundColor(.secondary)
            }
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
