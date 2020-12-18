import Combine
import SwiftUI

class PackageDetailViewModel: ObservableObject {
  struct Environment {
    var package: AnyPublisher<Package, Error>
  }

  enum State {
    case empty
    case loading
    case loaded(Package)
    case error(String)
  }

  @Published private(set) var state: State = .empty

  init(environment: Environment) {
    environment.package
      .map(State.loaded)
      .catch { _ in Just(.error("Failed to load package")) }
      .prepend(.loading)
      .receive(on: DispatchQueue.main)
      .assign(to: &$state)
  }

  init(package: Package) {
    state = .loaded(package)
  }
}

struct PackageDetailView: View {
  @ObservedObject var viewModel: PackageDetailViewModel

  var body: some View {
    switch viewModel.state {
    case .empty:
      PackageDetailPlaceholderView()
    case .loading:
      LoadingPackageDetailView()
    case .loaded(let package):
      LoadedPackageDetailView(package: package)
    case .error(let message):
      Text(message)
    }
  }
}

private struct LoadingPackageDetailView: View {
  var body: some View {
    ProgressView()
  }
}

private struct LoadedPackageDetailView: View {
  let package: Package

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Text(package.name)
          .font(.title)
        Spacer()
        Text(package.version)
          .font(.headline)
          .foregroundColor(.secondary)
      }
      Divider()
      if let description = package.description {
        Text(description)
      }
      Link(package.homepage.absoluteString, destination: package.homepage)
      Spacer()
    }
    .padding()
    .frame(minWidth: 300)
  }
}

struct PackageDetailPlaceholderView: View {
  var body: some View {
    Text("Select a Package")
      .font(.callout)
      .foregroundColor(.secondary)
  }
}
