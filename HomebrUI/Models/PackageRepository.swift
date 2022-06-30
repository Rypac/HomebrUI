import Combine
import Foundation

struct Packages {
  var formulae: [Package]
  var casks: [Package]
}

extension Packages {
  var count: Int { formulae.count + casks.count }
  var isEmpty: Bool { formulae.isEmpty && casks.isEmpty }
  var hasFormulae: Bool { !formulae.isEmpty }
  var hasCasks: Bool { !casks.isEmpty }
}

fileprivate struct ActivityState: Equatable {
  enum Action { case install, uninstall, update }
  enum Status { case started, completed, failed }

  var id: Package.ID
  var action: Action
  var status: Status
}

final class PackageRepository {
  private enum PackageState {
    case empty
    case loaded(Packages)
  }

  private enum RefreshState {
    case idle
    case refreshing
  }

  private enum Action: Equatable {
    case refresh(RefreshStrategy)
    case install(Package.ID)
    case uninstall(Package.ID)
  }

  private enum RefreshStrategy: Equatable {
    case installed
    case only(Package.ID)
  }

  private let packageState = CurrentValueSubject<PackageState, Never>(.empty)
  private let refreshState = CurrentValueSubject<RefreshState, Never>(.idle)
  private let activityState = PassthroughSubject<ActivityState, Never>()
  private let actions = PassthroughSubject<Action, Never>()
  private let homebrew: Homebrew

  private var cancellables = Set<AnyCancellable>()

  init(homebrew: Homebrew) {
    self.homebrew = homebrew

    actions
      .sink { [weak self] action in
        if let self, action == .refresh(.installed) {
          Task {
            await self.refresh()
          }
        }
      }
      .store(in: &cancellables)

    actions
      .compactMap { [homebrew] action -> AnyPublisher<ActivityState, Never>? in
        switch action {
        case .install(let id):
          return trackState { try await homebrew.installFormulae(ids: [id]) }
            .map { ActivityState(id: id, action: .install, status: $0) }
            .eraseToAnyPublisher()
        case .uninstall(let id):
          return trackState { try await homebrew.uninstallFormulae(ids: [id]) }
            .map { ActivityState(id: id, action: .install, status: $0) }
            .eraseToAnyPublisher()
        case .refresh:
          return nil
        }
      }
      .switchToLatest()
      .receive(on: DispatchQueue.main)
      .sink { [actions, packageState, activityState] state in
        switch (state.action, state.status) {
        case (.install, .completed):
          actions.send(.refresh(.installed))
          actions.send(.refresh(.only(state.id)))

        case (.uninstall, .completed):
          // Remove locally installed version before refresh occurs.
          if case var .loaded(packages) = packageState.value {
            if let index = packages.formulae.firstIndex(where: { $0.id == state.id }) {
              packages.formulae[index].installedVersion = nil
            } else if let index = packages.casks.firstIndex(where: { $0.id == state.id }) {
              packages.casks[index].installedVersion = nil
            }
            packageState.send(.loaded(packages))
          }

          actions.send(.refresh(.installed))
          actions.send(.refresh(.only(state.id)))

        default:
          break
        }

        activityState.send(state)
      }
      .store(in: &cancellables)
  }

  deinit {
    for cancellable in cancellables {
      cancellable.cancel()
    }
    cancellables.removeAll()
  }

  @MainActor
  func refresh() async {
    refreshState.send(.refreshing)

    let packages: Packages
    do {
      let info = try await homebrew.installedPackages()

      packages = Packages(
        formulae: info.formulae.compactMap { formulae in
          guard formulae.installed.first?.installedOnRequest == true else {
            return nil
          }
          return Package(formulae: formulae)
        },
        casks: info.casks.map(Package.init(cask:))
      )
    } catch {
      packages = Packages(formulae: [], casks: [])
    }

    refreshState.send(.idle)
    packageState.send(.loaded(packages))
  }

  func refresh(id: Package.ID) {
    actions.send(.refresh(.only(id)))
  }

  func install(id: Package.ID) {
    actions.send(.install(id))
  }

  func uninstall(id: Package.ID) {
    actions.send(.uninstall(id))
  }
}

private func trackState<OperationResult>(
  operation: @escaping () async throws -> OperationResult
) -> some Publisher<ActivityState.Status, Never> {
  Future { promise in
    Task {
      do {
        _ = try await operation()
        promise(.success(.completed))
      } catch {
        promise(.success(.failed))
      }
    }
  }
  .prepend(.started)
}

extension PackageRepository {
  var packages: some Publisher<Packages, Never> {
    packageState
      .compactMap { state in
        guard case let .loaded(packages) = state else {
          return nil
        }
        return packages
      }
  }

  var refreshing: some Publisher<Bool, Never> {
    refreshState
      .map { $0 == .refreshing }
  }

  func searchForPackage(withName query: String) -> some Publisher<Packages, Error> {
    homebrew.searchPublisher(for: query)
      .combineLatest(installedVersions.setFailureType(to: Error.self))
      .map { info, versions in
        var packages = Packages(formulae: [], casks: [])
        for formulae in info.formulae {
          var package = Package(formulae: formulae)
          package.installedVersion = versions[formulae.id]
          packages.formulae.append(package)
        }
        for cask in info.casks {
          var package = Package(cask: cask)
          package.installedVersion = versions[cask.id]
          packages.casks.append(package)
        }
        return packages
      }
  }

  private var installedVersions: some Publisher<[Package.ID: String], Never> {
    packageState
      .map { state in
        guard case let .loaded(packages) = state else {
          return [:]
        }
        var packageVersions: [Package.ID: String] = [:]
        for formulae in packages.formulae {
          packageVersions[formulae.id] = formulae.installedVersion
        }
        for cask in packages.casks {
          packageVersions[cask.id] = cask.installedVersion
        }
        return packageVersions
      }
  }

  func detail(for package: Package) -> some Publisher<PackageDetail, Error> {
    refreshedPackage(id: package.id)
      .prepend(package)
      .removeDuplicates()
      .map { [activityState] package in
        activityState
          .filter { $0.id == package.id }
          .scan(PackageDetail(package: package, activity: nil)) { detail, state in
            var detail = detail
            switch (state.action, state.status) {
            case (.uninstall, .started):
              detail.activity = .uninstalling
            case (.uninstall, .completed):
              detail.activity = nil
              detail.package.installedVersion = nil
            case (.install, .started):
              detail.activity = .installing
            case (.install, .completed):
              detail.activity = nil
              detail.package.installedVersion = package.latestVersion
            default:
              detail.activity = nil
            }
            return detail
          }
          .prepend(PackageDetail(package: package, activity: nil))
      }
      .switchToLatest()
  }

  private func refreshedPackage(id: Package.ID) -> some Publisher<Package, Error> {
    let installedPackageVersion = packageState
      .map { state -> String? in
        guard case let .loaded(packages) = state else {
          return nil
        }

        return packages[id]?.installedVersion
      }
      .setFailureType(to: Error.self)

    let refreshedPackage = actions
      .filter { $0 == .refresh(.only(id)) }
      .asyncTryMap { [homebrew] _ in
        let info = try await homebrew.info(for: [id])
        guard let package = info[id] else {
          throw MissingPackageError(id: id)
        }

        return package
      }

    return Publishers.CombineLatest(refreshedPackage, installedPackageVersion)
      .map { package, version in
        var package = package
        package.installedVersion = version
        return package
      }
  }
}

private extension Homebrew {
  func searchAsync(for query: String) async throws -> HomebrewInfo {
    let searchResult = try await search(for: query)

    async let formulaeInfo = info(for: searchResult.formulae)
    async let casksInfo = info(for: searchResult.casks)

    return try await HomebrewInfo(formulae: formulaeInfo.formulae, casks: casksInfo.casks)
  }

  func searchPublisher(for query: String) -> some Publisher<HomebrewInfo, Error> {
    Deferred {
      Future { promise in
        Task {
          do {
            promise(.success(try await searchAsync(for: query)))
          } catch {
            promise(.failure(error))
          }
        }
      }
    }
  }
}

private struct MissingPackageError: LocalizedError {
  let id: Package.ID
  var errorDescription: String { "Missing package \"\(id)\"" }
}

private extension Packages {
  subscript(id: Package.ID) -> Package? {
    formulae.first(where: { $0.id == id }) ?? casks.first(where: { $0.id == id })
  }
}

private extension HomebrewInfo {
  subscript(id: Package.ID) -> Package? {
    if let formulae = formulae.first(where: { $0.id == id }) {
      return Package(formulae: formulae)
    }
    if let cask = casks.first(where: { $0.id == id }) {
      return Package(cask: cask)
    }
    return nil
  }
}
