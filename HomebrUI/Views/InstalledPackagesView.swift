import Combine
import SwiftUI

final class InstalledPackagesViewModel: ObservableObject {
  struct Environment {
    var packages: AnyPublisher<InstalledPackages, Never>
    var isRefreshing: AnyPublisher<Bool, Never>
    var detail: (Package.ID) -> AnyPublisher<PackageDetail, Error>
    var load: (Package.ID) -> Void
    var install: (Package.ID) -> Void
    var uninstall: (Package.ID) -> Void
  }

  enum State {
    case empty
    case loading
    case loaded(InstalledPackages, refreshing: Bool)
  }

  @Published private(set) var packageState: State = .empty

  @Input var query: String = ""

  private let environment: Environment

  init(environment: Environment) {
    self.environment = environment

    Publishers
      .CombineLatest(environment.packages, $query.removeDuplicates())
      .map { packages, query in
        if query.isEmpty {
          return packages
        }
        return InstalledPackages(
          formulae: packages.formulae.filter { package in
            package.name.localizedCaseInsensitiveContains(query)
          },
          casks: packages.casks.filter { package in
            package.name.localizedCaseInsensitiveContains(query)
          }
        )
      }
      .combineLatest(environment.isRefreshing)
      .map(State.loaded)
      .prepend(.loading)
      .receive(on: DispatchQueue.main)
      .assign(to: &$packageState)
  }

  func uninstall(package: Package) {
    environment.uninstall(package.id)
  }

  func detailViewModel(for package: Package) -> PackageDetailViewModel {
    PackageDetailViewModel(
      environment: .init(
        package: environment.detail(package.id)
          .prepend(PackageDetail(package: package, activity: nil))
          .eraseToAnyPublisher(),
        load: { [load = environment.load] in load(package.id) },
        install: { [install = environment.install] in install(package.id) },
        uninstall: { [uninstall = environment.uninstall] in uninstall(package.id) }
      )
    )
  }
}

extension InstalledPackagesViewModel {
  convenience init(repository: PackageRepository) {
    self.init(
      environment: Environment(
        packages: repository.packages,
        isRefreshing: repository.refreshing,
        detail: repository.detail,
        load: repository.refresh,
        install: repository.install,
        uninstall: repository.uninstall
      )
    )
  }
}

struct InstalledPackagesView: View {
  @StateObject var viewModel: InstalledPackagesViewModel

  @Environment(\.openURL) private var openURL

  @State private var selection: Package.ID?

  var body: some View {
    VStack(spacing: 0) {
      switch viewModel.packageState {
      case .empty:
        PackageFilterView(query: $viewModel.query)
        Spacer()
      case .loading:
        ProgressView()
      case let .loaded(packages, isRefreshing):
        PackageFilterView(query: $viewModel.query)
        PackageListView(
          packages: packages,
          detailViewModel: viewModel.detailViewModel,
          selection: $selection,
          action: { action in
            switch action {
            case .viewHomepage(let package):
              openURL(package.homepage)
            case .uninstall(let package):
              viewModel.uninstall(package: package)
            }
          }
        )
        Spacer(minLength: 0)
        if isRefreshing {
          PackageRefreshIndicator()
        }
      }
    }
    .frame(minWidth: 250, maxWidth: 300)
  }
}

private struct PackageFilterView: View {
  @Binding var query: String

  var body: some View {
    TextField("Filter", text: $query)
      .textFieldStyle(RoundedBorderTextFieldStyle())
      .padding(8)
  }
}

private struct PackageListView: View {
  enum Action {
    case viewHomepage(Package)
    case uninstall(Package)
  }

  let packages: InstalledPackages
  let detailViewModel: (Package) -> PackageDetailViewModel
  @Binding var selection: Package.ID?
  let action: (Action) -> Void

  var body: some View {
    List {
      if packages.hasFormulae {
        Section(header: Text("Formulae")) {
          ForEach(packages.formulae, content: packageRow)
        }
      }
      if packages.hasFormulae && packages.hasCasks {
        Divider()
      }
      if packages.hasCasks {
        Section(header: Text("Casks")) {
          ForEach(packages.casks, content: packageRow)
        }
      }
    }
  }

  private func packageRow(_ package: Package) -> some View {
    NavigationLink(
      destination: PackageDetailView(viewModel: detailViewModel(package)),
      tag: package.id,
      selection: $selection
    ) {
      HStack {
        Text(package.name)
          .layoutPriority(1)
        Spacer()
        if let version = package.installedVersion {
          Text(version)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }
    }
    .contextMenu {
      Button("View Homepage") {
        action(.viewHomepage(package))
      }
      Divider()
      Button("Uninstall") {
        action(.uninstall(package))
      }
    }
  }
}

private struct PackageRefreshIndicator: View {
  var body: some View {
    VStack {
      Divider()
      HStack {
        Text("Refreshing")
          .font(.callout)
        Spacer()
        ProgressView()
          .scaleEffect(0.5)
      }
      .padding([.leading, .trailing])
      .padding(.bottom, 8)
    }
  }
}

private extension InstalledPackages {
  var hasFormulae: Bool { !formulae.isEmpty }
  var hasCasks: Bool { !casks.isEmpty }
}
