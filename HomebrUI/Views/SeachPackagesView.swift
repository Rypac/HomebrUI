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
    var install: (Package.ID) -> Void
    var uninstall: (Package.ID) -> Void
  }

  enum State {
    case empty
    case loading
    case loaded([SearchResult])
    case noResults
    case error(String)
  }

  enum Action {
    case search
    case retry
  }

  @Published private(set) var state: State = .empty

  @Input var query: String = ""

  private let actions = PassthroughSubject<Action, Never>()
  private let environment: Environment

  init(environment: Environment) {
    self.environment = environment

    let clearSearch = $query.filter(\.isEmpty)
    let runSearch = actions.compactMap { $0 == .search ? self.query : nil }.removeDuplicates()
    let retrySearch = actions.compactMap { $0 == .retry ? self.query : nil }

    Publishers
      .Merge3(clearSearch, runSearch, retrySearch)
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
    actions.send(.search)
  }

  func retry() {
    actions.send(.retry)
  }

  func detailViewModel(for searchResult: SearchResult) -> PackageDetailViewModel {
    PackageDetailViewModel(
      environment: .init(
        package: environment.info(searchResult.id),
        install: environment.install,
        uninstall: environment.uninstall
      )
    )
  }
}

extension SearchPackagesViewModel {
  convenience init(repository: PackageRepository) {
    self.init(
      environment: Environment(
        search: repository.searchForPackage,
        info: repository.info,
        install: repository.install,
        uninstall: repository.uninstall
      )
    )
  }
}

struct SearchPackagesView: View {
  @ObservedObject var viewModel: SearchPackagesViewModel

  var body: some View {
    VStack(spacing: 0) {
      PackageSearchField(query: $viewModel.query, submit: viewModel.search)
      switch viewModel.state {
      case .empty:
        SearchInfoView()
      case .loading:
        SearchLoadingView()
      case .loaded(let results):
        SearchResultsView(results: results, detailViewModel: viewModel.detailViewModel)
      case .noResults:
        NoSearchResultsView()
      case .error(let message):
        FailedToLoadSearchResultsView(message: message, retry: viewModel.retry)
      }
      Spacer(minLength: 0)
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
  let detailViewModel: (SearchResult) -> PackageDetailViewModel

  var body: some View {
    List {
      Section(header: Text("\(results.count) results")) {
        ForEach(results) { result in
          NavigationLink(
            result.name,
            destination: PackageDetailView(viewModel: detailViewModel(result))
          )
        }
      }
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
