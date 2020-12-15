import Combine
import SwiftUI

class ContentViewModel: ObservableObject {
  enum State: Equatable {
    case idle
    case loading
    case loadedPackages(String)
    case failedToLoad(String)
  }

  @Published private(set) var state: State = .idle

  private let triggerLoad = PassthroughSubject<Bool, Never>()

  init(homebrew: Homebrew = Homebrew()) {
    triggerLoad
      .filter { isLoading in !isLoading }
      .flatMap { _ in
        homebrew.list()
          .map(State.loadedPackages)
          .catch { error in
            Just(.failedToLoad(error.localizedDescription))
              .setFailureType(to: Never.self)
          }
          .prepend(.loading)
      }
      .assign(to: &$state)
  }

  func loadPackages() {
    triggerLoad.send(state == .loading)
  }
}

struct ContentView: View {
  @StateObject var viewModel = ContentViewModel()

  var body: some View {
    VStack {
      Text(viewModel.state.status)
    }
    .padding()
    .frame(width: 500, height: 400, alignment: .center)
    .onAppear {
      viewModel.loadPackages()
    }
  }
}

private extension ContentViewModel.State {
  var status: String {
    switch self {
    case .idle: return "Idle"
    case .loading: return "Loading…"
    case .loadedPackages(let output): return output
    case .failedToLoad(let error): return error
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
