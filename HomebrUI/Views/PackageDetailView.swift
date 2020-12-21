import Combine
import SwiftUI

class PackageDetailViewModel: ObservableObject {
  struct Environment {
    var package: AnyPublisher<Package, Error>
    var install: (Package.ID) -> Void
    var uninstall: (Package.ID) -> Void
  }

  enum State {
    case empty
    case loading
    case loaded(Package)
    case error(String)
  }

  @Published private(set) var state: State = .empty

  private let load = PassthroughSubject<Void, Never>()
  private let environment: Environment

  init(environment: Environment) {
    self.environment = environment
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

  init(environment: Environment, package: Package) {
    self.environment = environment
    self.state = .loaded(package)
  }

  func loadPackage() {
    load.send()
  }

  func install(id: Package.ID) {
    environment.install(id)
  }

  func uninstall(id: Package.ID) {
    environment.uninstall(id)
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
      LoadedPackageDetailView(package: package) { action in
        switch action {
        case .install: viewModel.install(id: package.id)
        case .uninstall: viewModel.uninstall(id: package.id)
        }
      }
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
  enum Action {
    case install
    case uninstall
  }

  let package: Package
  let action: (Action) -> Void

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Text(package.name)
          .font(.title)
        Spacer()
        if package.isInstalled {
          ActionButton("Uninstall") {
            action(.uninstall)
          }
        } else {
          ActionButton("Install") {
            action(.install)
          }
        }
      }
      Divider()
      if let description = package.description {
        Text(description)
      }
      Link(package.homepage.absoluteString, destination: package.homepage)
      if let version = package.installedVersion {
        HStack(spacing: 8) {
          Text("Installed Version:")
          Text(version)
            .foregroundColor(.secondary)
        }
      }
      HStack(spacing: 8) {
        Text("Latest Version:")
        Text(package.latestVersion)
          .foregroundColor(.secondary)
      }
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

private struct ActionButton: View {
  let title: String
  let action: () -> Void

  init(_ title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }

  var body: some View {
    Button(title, action: action)
      .buttonStyle(ActionButtonStyle())
  }
}

struct ActionButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .padding(.vertical, 6)
      .padding(.horizontal, 12)
      .foregroundColor(.white)
      .background(
        RoundedRectangle(cornerRadius: .infinity, style: .continuous)
          .fill(Color.blue)
      )
  }
}
