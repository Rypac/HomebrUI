import Combine
import SwiftUI

struct SearchResult: Identifiable {
  let id: Package.ID
  var name: String { id.rawValue }
}

class SearchPackagesViewModel: ObservableObject {
  struct Environment {
    var search: (String) -> AnyPublisher<[Package.ID], Error>
    var info: (Package.ID) -> AnyPublisher<Package, Error>
  }

  enum State {
    case empty
    case loading
    case loaded([SearchResult])
    case noResults
    case error(String)
  }

  @Published private(set) var state: State = .empty

  @Input var query: String = ""

  private let executeSearch = PassthroughSubject<Void, Never>()
  private let environment: Environment

  init(environment: Environment) {
    self.environment = environment

    let clearQuery = $query.filter(\.isEmpty)
    let executeQuery = executeSearch.map { self.query }

    Publishers
      .Merge(clearQuery, executeQuery)
      .map { query -> AnyPublisher<State, Never> in
        if query.isEmpty {
          return .just(.empty)
        }
        return environment.search(query)
          .map { results in
            guard !results.isEmpty else {
              return .noResults
            }
            return .loaded(results.map(SearchResult.init))
          }
          .prepend(.loading)
          .catch { _ in Just(.error("Failed to load results")) }
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .receive(on: DispatchQueue.main)
      .assign(to: &$state)
  }

  func search() {
    executeSearch.send()
  }

  func showPackage(forResult searchResult: SearchResult) -> AnyPublisher<Package, Error> {
    environment.info(searchResult.id)
  }
}

extension SearchPackagesViewModel {
  convenience init(repository: PackageRepository) {
    self.init(
      environment: Environment(
        search: repository.searchForPackage,
        info: repository.info
      )
    )
  }
}

struct SearchPackagesView: View {
  @ObservedObject var viewModel: SearchPackagesViewModel

  var body: some View {
    VStack {
      PackageSearchField(query: $viewModel.query, submit: viewModel.search)
      switch viewModel.state {
      case .empty:
        SearchInfoView()
      case .loading:
        SearchLoadingView()
      case .loaded(let results):
        SearchResultsView(results: results, loadPackage: viewModel.showPackage)
      case .noResults:
        NoSearchResultsView()
      case .error(let message):
        FailedToLoadSearchResultsView(message: message, retry: viewModel.search)
      }
      Spacer()
    }
  }
}

private struct PackageSearchField: View {
  @Binding var query: String

  var submit: () -> Void

  var body: some View {
    TextField("Search", text: $query, onCommit: submit)
      .disableAutocorrection(true)
      .textFieldStyle(RoundedBorderTextFieldStyle())
      .padding(8)
  }
}

private struct SearchInfoView: View {
  var body: some View {
    Spacer()
    Text("Search for a Homebrew package")
  }
}

private struct SearchLoadingView: View {
  var body: some View {
    Spacer()
    ProgressView()
  }
}

private struct SearchResultsView: View {
  let results: [SearchResult]
  let loadPackage: (SearchResult) -> AnyPublisher<Package, Error>

  var body: some View {
    List(results) { result in
      NavigationLink(
        result.name,
        destination: PackageDetailView(
          viewModel: PackageDetailViewModel(
            environment: .init(package: loadPackage(result))
          )
        )
      )
    }
  }
}

private struct NoSearchResultsView: View {
  var body: some View {
    Spacer()
    Text("No packages found")
  }
}

private struct FailedToLoadSearchResultsView: View {
  let message: String
  let retry: () -> Void

  var body: some View {
    Spacer()
    Text(message)
    Button("Retry", action: retry)
  }
}
