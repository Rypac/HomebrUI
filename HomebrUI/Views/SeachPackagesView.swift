import Combine
import SwiftUI

final class SearchPackagesViewModel: ObservableObject {
  struct Environment {
    var search: (String) -> AnyPublisher<Packages, Error>
    var detail: (Package) -> AnyPublisher<PackageDetail, Error>
    var load: (Package.ID) -> Void
    var install: (Package.ID) -> Void
    var uninstall: (Package.ID) -> Void
  }

  enum State {
    case empty
    case loading
    case loaded(Packages)
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

    let executeSearch = $query
      .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
      .merge(with: actions.compactMap { [weak self] in $0 == .search ? self?.query : nil })
      .removeDuplicates()
      .merge(with: actions.compactMap { [weak self] in $0 == .retry ? self?.query : nil })
      .filter { !$0.isEmpty }

    let clearSearch = $query.filter(\.isEmpty)

    Publishers.Merge(executeSearch, clearSearch)
      .map { query -> AnyPublisher<State, Never> in
        if query.isEmpty {
          return .just(.empty)
        }
        return environment.search(query)
          .map { packages in
            guard !packages.isEmpty else {
              return .noResults
            }
            return .loaded(packages)
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

  func detailViewModel(for package: Package) -> PackageDetailViewModel {
    PackageDetailViewModel(
      environment: .init(
        package: environment.detail(package),
        load: { [load = environment.load] in load(package.id) },
        install: { [install = environment.install] in install(package.id) },
        uninstall: { [uninstall = environment.uninstall] in uninstall(package.id) }
      ),
      packageDetail: PackageDetail(package: package, activity: nil)
    )
  }
}

extension SearchPackagesViewModel {
  convenience init(repository: PackageRepository) {
    self.init(
      environment: Environment(
        search: { repository.searchForPackage(withName: $0).eraseToAnyPublisher() },
        detail: { repository.detail(for: $0).eraseToAnyPublisher() },
        load: repository.refresh,
        install: repository.install,
        uninstall: repository.uninstall
      )
    )
  }
}

struct SearchPackagesView: View {
  @StateObject var viewModel: SearchPackagesViewModel

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
      .textFieldStyle(.roundedBorder)
      .padding(8)
  }
}

private struct SearchInfoView: View {
  var body: some View {
    Spacer()
    Text("Search for a Homebrew package")
      .font(.callout)
      .foregroundColor(.secondary)
  }
}

private struct SearchLoadingView: View {
  var body: some View {
    Spacer()
    ProgressView()
  }
}

private struct SearchResultsView: View {
  let results: Packages
  let detailViewModel: (Package) -> PackageDetailViewModel

  var body: some View {
    List {
      if results.hasFormulae {
        SearchResultsSectionView(
          title: "Formulae",
          results: results.formulae,
          detailViewModel: detailViewModel
        )
      }
      if results.hasFormulae && results.hasCasks {
        Divider()
      }
      if results.hasCasks {
        SearchResultsSectionView(
          title: "Casks",
          results: results.casks,
          detailViewModel: detailViewModel
        )
      }
    }
  }
}

private struct SearchResultsSectionView: View {
  let title: String
  let results: [Package]
  let detailViewModel: (Package) -> PackageDetailViewModel

  var body: some View {
    Section(
      header: HStack {
        Text(title)
        Spacer(minLength: 8)
        if results.count == 1 {
          Text("\(results.count) result")
        } else {
          Text("\(results.count) results")
        }
      }
    ) {
      ForEach(results) { result in
        NavigationLink(result.name) {
          PackageDetailView(viewModel: detailViewModel(result))
        }
      }
    }
  }
}

private struct NoSearchResultsView: View {
  var body: some View {
    Spacer()
    Text("No packages found")
      .font(.callout)
      .foregroundColor(.secondary)
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
