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
    enum Status { case started, completed, failed }

    var action: Action
    var status: Status
  }

  private enum Action: Equatable {
    case refresh
    case install(Package.ID)
    case uninstall(Package.ID)
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
      .filter { $0 == .refresh }
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
        guard case let .install(id) = action else { return nil }
        return homebrew.installFormulae(ids: [id])
          .map { _ in ActivityState(action: action, status: .completed) }
          .catch { _ in Just(ActivityState(action: action, status: .failed)) }
          .prepend(ActivityState(action: action, status: .started))
          .eraseToAnyPublisher()
      }

    let uninstallPackage = actions
      .compactMap { action -> AnyPublisher<ActivityState, Never>? in
        guard case let .uninstall(id) = action else { return nil }
        return homebrew.uninstallFormulae(ids: [id])
          .map { _ in ActivityState(action: action, status: .completed) }
          .catch { _ in Just(ActivityState(action: action, status: .failed)) }
          .prepend(ActivityState(action: action, status: .started))
          .eraseToAnyPublisher()
      }

    Publishers.Merge(installPackage, uninstallPackage)
      .switchToLatest()
      .sink { [actions, packageState, activityState] state in
        switch (state.action, state.status) {
        case (.install, .completed):
          actions.send(.refresh)
        case let (.uninstall(id), .completed):
          // Remove locally installed version before refresh occurs.
          if case var .loaded(packages) = packageState.value {
            if let index = packages.formulae.firstIndex(where: { $0.id == id }) {
              packages.formulae[index].installedVersion = nil
            } else if let index = packages.casks.firstIndex(where: { $0.id == id }) {
              packages.casks[index].installedVersion = nil
            }
            packageState.send(.loaded(packages))
          }

          actions.send(.refresh)
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
    actions.send(.refresh)
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

  func searchForPackage(withName query: String) -> AnyPublisher<[Package.ID], Error> {
    homebrew.search(for: query)
  }

  func info(for packageID: Package.ID) -> AnyPublisher<PackageDetail, Error> {
    actions
      .prepend(.refresh)
      .filter { $0 == .refresh }
      .map { [homebrew] _ in
        homebrew.packageInfo(for: [packageID])
          .tryMap { packages in
            guard let package = packages.first(where: { $0.id == packageID }) else {
              throw PackageInfoError.missingPackage(packageID)
            }
            return package
          }
      }
      .switchToLatest()
      .map { [activityState] package in
        activityState
          .filter { state in
            switch state.action {
            case .install(package.id), .uninstall(package.id): return true
            default: return false
            }
          }
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
}

private enum PackageInfoError: LocalizedError {
  case missingPackage(Package.ID)
  case invalidPackageCount(expected: Int, actual: Int)

  var errorDescription: String {
    switch self {
    case let .missingPackage(id):
      return "Missing package \"\(id)\""
    case let .invalidPackageCount(expected, actual):
      return "Expected \(expected) packages but received \(actual)"
    }
  }
}

private extension Homebrew {
  func packageInfo(for ids: [Package.ID]) -> AnyPublisher<[Package], Error> {
    info(for: ids)
      .tryMap { info in
        let fomulae = info.formulae.compactMap { formulae -> Package? in
          guard ids.contains(formulae.id) else {
            return nil
          }
          return Package(formulae: formulae)
        }
        let casks = info.casks.compactMap { cask -> Package? in
          guard ids.contains(cask.id) else {
            return nil
          }
          return Package(cask: cask)
        }

        let packages = fomulae + casks

        guard packages.count == ids.count else {
          throw PackageInfoError.invalidPackageCount(
            expected: ids.count,
            actual: packages.count
          )
        }

        return packages
      }
      .eraseToAnyPublisher()
  }
}
