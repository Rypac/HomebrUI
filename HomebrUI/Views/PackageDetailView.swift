import Combine
import SwiftUI

enum PackageStatus {
  case installing
  case updating
  case uninstalling
}

class PackageDetailViewModel: ObservableObject {
  struct Environment {
    var package: AnyPublisher<Package, Error>
    var status: AnyPublisher<PackageStatus?, Never>
    var install: (Package.ID) -> Void
    var uninstall: (Package.ID) -> Void
  }

  enum State {
    case empty
    case loading
    case loaded(Package, status: PackageStatus?)
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
          .combineLatest(environment.status.setFailureType(to: Error.self))
          .map(State.loaded)
          .catch { _ in Just(.error("Failed to load package")) }
          .prepend(.loading)
      }
      .switchToLatest()
      .receive(on: DispatchQueue.main)
      .assign(to: &$state)
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
      EmptyPackageDetailView()
        .onAppear(perform: viewModel.loadPackage)
    case .loading:
      LoadingPackageDetailView()
    case .loaded(let package, let status):
      LoadedPackageDetailView(package: package, status: status) { action in
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

private struct EmptyPackageDetailView: View {
  var body: some View {
    Color.clear
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
  let status: PackageStatus?
  let action: (Action) -> Void

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Text(package.name)
          .font(.title)
        Spacer()
        if status == .installing || status == .uninstalling {
          ProgressView()
            .scaleEffect(0.5)
        }
        if package.isInstalled {
          ActionButton("Uninstall") {
            action(.uninstall)
          }
          .disabled(status == .uninstalling)
        } else {
          ActionButton("Install") {
            action(.install)
          }
          .disabled(status == .installing)
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
