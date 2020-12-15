import Combine
import SwiftUI

class ContentViewModel: ObservableObject {
  enum State: Equatable {
    case idle
    case loading
    case loadedPackages([Package])
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
      .receive(on: DispatchQueue.main)
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
      switch viewModel.state {
      case .idle, .loading:
        Text("Loading…")
      case .loadedPackages(let packages):
        List(packages) { package in
          HStack {
            Text(package.name)
            Spacer()
            Text(package.version)
              .foregroundColor(.secondary)
          }
        }
      case .failedToLoad(let error):
        Text(error)
      }
    }
    .padding()
    .frame(minWidth: 200, minHeight: 100)
    .onAppear {
      viewModel.loadPackages()
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
