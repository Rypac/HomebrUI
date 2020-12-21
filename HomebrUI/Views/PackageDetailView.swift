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

  private let load = PassthroughSubject<Void, Never>()

  init(environment: Environment) {
    load
      .map {
        environment.package
          .map(State.loaded)
          .catch { _ in Just(.error("Failed to load package")) }
          .prepend(.loading)
      }
      .switchToLatest()
      .receive(on: DispatchQueue.main)
      .assign(to: &$state)
  }

  init(package: Package) {
    state = .loaded(package)
  }

  func loadPackage() {
    load.send()
  }
}

struct PackageDetailView: View {
  @ObservedObject var viewModel: PackageDetailViewModel

  var body: some View {
    switch viewModel.state {
    case .empty:
      PackageDetailPlaceholderView()
        .onAppear {
          viewModel.loadPackage()
        }
    case .loading:
      LoadingPackageDetailView()
    case .loaded(let package):
      LoadedPackageDetailView(package: package)
    case .error(let message):
      FailedToLoadPackageView(message: message, retry: viewModel.loadPackage)
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
        if let version = package.installedVersion {
          Text(version)
            .font(.headline)
            .foregroundColor(.secondary)
        }
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

struct FailedToLoadPackageView: View {
  let message: String
  let retry: () -> Void

  var body: some View {
    VStack {
      Text(message)
      Button("Retry", action: retry)
    }
  }
}
