import Combine
import Foundation

struct InstalledPackages {
  var formulae: [Package]
  var casks: [Package]
}

final class PackageRepository {
  private enum PackageState {
    case empty
    case loaded(InstalledPackages)
  }

  private enum RefreshState {
    case idle
    case refreshing
  }

  private struct ActivityState {
    enum Action { case install, uninstall }
    enum Status { case started, completed, failed }

    var id: Package.ID
    var action: Action
    var status: Status
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
      .filter { $0 == .refresh(.installed) }
      .map { [refreshState] _ in
        homebrew.installedPackages()
          .handleEvents(
            receiveSubscription: { _ in
              refreshState.send(.refreshing)
            },
            receiveCompletion: { _ in
              refreshState.send(.idle)
            }
          )
          .map { info in
            InstalledPackages(
              formulae: info.formulae.compactMap { formulae in
                guard formulae.installed.first?.installedOnRequest == true else {
                  return nil
                }
                return Package(formulae: formulae)
              },
              casks: info.casks.map(Package.init(cask:))
            )
          }
          .catch { _ in
            Just(InstalledPackages(formulae: [], casks: []))
          }
      }
      .switchToLatest()
      .receive(on: DispatchQueue.main)
      .sink { [packageState] installedPackages in
        packageState.send(.loaded(installedPackages))
      }
      .store(in: &cancellables)

    let installPackage = actions
      .compactMap { action -> AnyPublisher<ActivityState, Never>? in
        guard case let .install(id) = action else {
          return nil
        }
        return homebrew.installFormulae(ids: [id])
          .map { _ in .completed }
          .catch { _ in Just(.failed) }
          .prepend(.started)
          .map { ActivityState(id: id, action: .install, status: $0) }
          .eraseToAnyPublisher()
      }

    let uninstallPackage = actions
      .compactMap { action -> AnyPublisher<ActivityState, Never>? in
        guard case let .uninstall(id) = action else {
          return nil
        }
        return homebrew.uninstallFormulae(ids: [id])
          .map { _ in .completed }
          .catch { _ in Just(.failed) }
          .prepend(.started)
          .map { ActivityState(id: id, action: .uninstall, status: $0) }
          .eraseToAnyPublisher()
      }

    Publishers.Merge(installPackage, uninstallPackage)
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
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
    cancellables.removeAll()
  }

  func refresh() {
    actions.send(.refresh(.installed))
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

extension PackageRepository {
  var packages: AnyPublisher<InstalledPackages, Never> {
    packageState
      .compactMap { state in
        guard case let .loaded(packages) = state else {
          return nil
        }
        return packages
      }
      .eraseToAnyPublisher()
  }

  var refreshing: AnyPublisher<Bool, Never> {
    refreshState
      .map { $0 == .refreshing }
      .eraseToAnyPublisher()
  }

  func searchForPackage(withName query: String) -> AnyPublisher<[Package], Error> {
    homebrew.search(for: query)
      .map { [homebrew] result in
        Publishers.Zip(
          homebrew.info(for: result.formulae).map(\.formulae),
          homebrew.info(for: result.casks).map(\.casks)
        )
        .map(HomebrewInfo.init)
      }
      .switchToLatest()
      .combineLatest(installedVersions.setFailureType(to: Error.self))
      .map { info, versions in
        var packages: [Package] = []
        info.formulae.forEach { formulae in
          var package = Package(formulae: formulae)
          package.installedVersion = versions[formulae.id]
          packages.append(package)
        }
        info.casks.forEach { cask in
          var package = Package(cask: cask)
          package.installedVersion = versions[cask.id]
          packages.append(package)
        }
        return packages
      }
      .eraseToAnyPublisher()
  }

  var installedVersions: AnyPublisher<[Package.ID: String], Never> {
    packageState
      .map { state in
        guard case let .loaded(packages) = state else {
          return [:]
        }
        var packageVersions: [Package.ID: String] = [:]
        packages.formulae.forEach { packageVersions[$0.id] = $0.installedVersion }
        packages.casks.forEach { packageVersions[$0.id] = $0.installedVersion }
        return packageVersions
      }
      .eraseToAnyPublisher()
  }

  func detail(for package: Package) -> AnyPublisher<PackageDetail, Error> {
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
            case (.install, .started), (.install, .completed):
              detail.activity = .installing
            default:
              detail.activity = nil
            }
            return detail
          }
          .prepend(PackageDetail(package: package, activity: nil))
      }
      .switchToLatest()
      .eraseToAnyPublisher()
  }

  private func refreshedPackage(id: Package.ID) -> AnyPublisher<Package, Error> {
    let installedPackageVersion = packageState
      .map { state -> String? in
        guard case let .loaded(packages) = state else {
          return nil
        }

        return packages[id]?.installedVersion
      }
      .setFailureType(to: Error.self)

    let refreshedPackage = actions
      .compactMap { [homebrew] action -> AnyPublisher<Package, Error>? in
        guard case .refresh(.only(id)) = action else {
          return nil
        }

        return homebrew.info(for: [id])
          .tryMap { info in
            guard let package = info[id] else {
              throw MissingPackageError(id: id)
            }
            return package
          }
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .eraseToAnyPublisher()

    return Publishers.CombineLatest(refreshedPackage, installedPackageVersion)
      .map { package, version in
        var package = package
        package.installedVersion = version
        return package
      }
      .eraseToAnyPublisher()
  }
}

private struct MissingPackageError: LocalizedError {
  let id: Package.ID
  var errorDescription: String { "Missing package \"\(id)\"" }
}

private extension InstalledPackages {
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
