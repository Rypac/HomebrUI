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

  private let repository: PackageRepository

  init(repository: PackageRepository = PackageRepository()) {
    self.repository = repository

    repository.packages
      .map(State.loadedPackages)
      .receive(on: DispatchQueue.main)
      .assign(to: &$state)
  }

  func loadPackages() {
    repository.refresh()
  }
}

struct PackageView: View {
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
    .onAppear {
      viewModel.loadPackages()
    }
  }
}

struct ContentView: View {
  var body: some View {
    NavigationView {
      PackageView()
        .frame(minWidth: 200)
        .listStyle(SidebarListStyle())
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
