import Combine
import Foundation

struct InstalledPackages {
  var formulae: [Package]
  var casks: [Package]
}

class PackageRepository {
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
          homebrew.info(for: result.formulae)
            .map { $0.formulae.map(Package.init(formulae:)) },
          homebrew.info(for: result.casks)
            .map { $0.casks.map(Package.init(cask:)) }
        )
        .map(+)
      }
      .switchToLatest()
      .eraseToAnyPublisher()
  }

  func detail(for packageID: Package.ID) -> AnyPublisher<PackageDetail, Error> {
    package(id: packageID)
      .map { [activityState] package in
        activityState
          .filter { $0.id == packageID }
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

  private func package(id: Package.ID) -> AnyPublisher<Package, Error> {
    actions
      .compactMap { [homebrew] action -> AnyPublisher<Package, Error>? in
        guard case .refresh(.only(id)) = action else {
          return nil
        }

        return homebrew.info(for: [id])
          .tryMap { info in
            guard let package = info.packages.first(where: { $0.id == id }) else {
              throw MissingPackageError(id: id)
            }
            return package
          }
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .eraseToAnyPublisher()
  }
}

private struct MissingPackageError: LocalizedError {
  let id: Package.ID
  var errorDescription: String { "Missing package \"\(id)\"" }
}

private extension HomebrewInfo {
  var packages: [Package] {
    formulae.map(Package.init(formulae:)) + casks.map(Package.init(cask:))
  }
}
