import Combine
import SwiftUI

final class PackageDetailViewModel: ObservableObject {
  struct Environment {
    var package: AnyPublisher<PackageDetail, Error>
    var load: () -> Void
    var install: () -> Void
    var uninstall: () -> Void
  }

  enum State {
    case empty
    case loading
    case loaded(PackageDetail)
    case error(String)
  }

  @Published private(set) var state: State = .empty

  private let environment: Environment

  init(environment: Environment, packageDetail: PackageDetail? = nil) {
    self.environment = environment

    if let packageDetail {
      state = .loaded(packageDetail)
    }

    environment.package
      .map(State.loaded)
      .catch { _ in Just(.error("Failed to load package")) }
      .receive(on: DispatchQueue.main)
      .assign(to: &$state)
  }

  func load() {
    state = .loading
    environment.load()
  }

  func install() {
    environment.install()
  }

  func uninstall() {
    environment.uninstall()
  }
}

struct PackageDetailView: View {
  @StateObject var viewModel: PackageDetailViewModel

  var body: some View {
    switch viewModel.state {
    case .empty:
      PackageDetailPlaceholderView()
    case .loading:
      LoadingPackageDetailView()
    case .loaded(let package):
      LoadedPackageDetailView(package: package) { action in
        switch action {
        case .install: viewModel.install()
        case .uninstall: viewModel.uninstall()
        }
      }
    case .error(let message):
      FailedToLoadPackageView(message: message, retry: viewModel.load)
    }
  }
}

struct PackageDetailPlaceholderView: View {
  var body: some View {
    Text("Select a Package")
      .font(.callout)
      .foregroundColor(.secondary)
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

  let package: PackageDetail
  let action: (Action) -> Void

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Text(package.name)
          .font(.title)
        Spacer()
        if package.activity != nil {
          ProgressView()
            .scaleEffect(0.5)
        }
        if package.isInstalled {
          ActionButton("Uninstall") {
            action(.uninstall)
          }
          .disabled(package.activity == .uninstalling)
        } else {
          ActionButton("Install") {
            action(.install)
          }
          .disabled(package.activity == .installing)
        }
      }
      Divider()
      if let description = package.description {
        Text(description)
      }
      Link(package.homepage.absoluteString, destination: package.homepage)
      if let version = package.installedVersion {
        Text("Installed Version: ") + Text(version).foregroundColor(.secondary)
      }
      Text("Latest Version: ") + Text(package.latestVersion).foregroundColor(.secondary)
      Spacer(minLength: 0)
    }
    .padding()
    .frame(minWidth: 300)
  }
}

private struct FailedToLoadPackageView: View {
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
