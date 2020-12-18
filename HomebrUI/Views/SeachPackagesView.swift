import Combine
import SwiftUI

class SearchPackagesViewModel: ObservableObject {
  struct Environment {
    var search: (String) -> AnyPublisher<[String], Error>
  }

  enum State {
    case empty
    case loading
    case loaded([String])
  }

  @Published private(set) var state: State = .empty

  @Input var query: String = ""

  private let executeSearch = PassthroughSubject<Void, Never>()

  init(environment: Environment) {
    let clearQuery = $query.filter(\.isEmpty)
    let executeQuery = executeSearch.map { self.query }

    Publishers
      .Merge(clearQuery, executeQuery)
      .removeDuplicates()
      .map { query -> AnyPublisher<State, Never> in
        if query.isEmpty {
          return .just(.empty)
        }
        return environment.search(query)
          .map(State.loaded)
          .prepend(.loading)
          .catch { _ in Just(.empty) }
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .receive(on: DispatchQueue.main)
      .assign(to: &$state)
  }

  func search() {
    executeSearch.send()
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
        SearchResultsView(results: results)
      }
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
    Spacer()
  }
}

private struct SearchLoadingView: View {
  var body: some View {
    Spacer()
    ProgressView()
    Spacer()
  }
}

private struct SearchResultsView: View {
  let results: [String]

  var body: some View {
    List(results, id: \.self) { result in
      Text(result)
    }
    Spacer()
  }
}
