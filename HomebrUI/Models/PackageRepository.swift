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
    enum Action: Equatable {
      case install(Status)
      case uninstall(Status)
    }

    var id: Package.ID
    var action: Action
  }

  private let packageState = CurrentValueSubject<PackageState, Never>(.empty)
  private let refreshState = CurrentValueSubject<RefreshState, Never>(.idle)
  private let activityState = PassthroughSubject<ActivityState, Never>()
  private let refreshAction = PassthroughSubject<Void, Never>()
  private let homebrew: Homebrew

  private var cancellables = Set<AnyCancellable>()

  init(homebrew: Homebrew) {
    self.homebrew = homebrew

    refreshAction
      .map { [refreshState] in
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

    let installPackage = activityState
      .compactMap { state -> AnyPublisher<ActivityState, Never>? in
        guard case .install(.started) = state.action else { return nil }
        return homebrew.installFormulae(ids: [state.id])
          .map { _ in ActivityState(id: state.id, action: .install(.completed)) }
          .catch { _ in Just(ActivityState(id: state.id, action: .install(.failed))) }
          .prepend(state)
          .eraseToAnyPublisher()
      }

    let uninstallPackage = activityState
      .compactMap { state -> AnyPublisher<ActivityState, Never>? in
        guard case .uninstall(.started) = state.action else { return nil }
        return homebrew.uninstallFormulae(ids: [state.id])
          .map { _ in ActivityState(id: state.id, action: .uninstall(.completed)) }
          .catch { _ in Just(ActivityState(id: state.id, action: .uninstall(.failed))) }
          .prepend(state)
          .eraseToAnyPublisher()
      }

    Publishers.Merge(installPackage, uninstallPackage)
      .switchToLatest()
      .sink { [refreshAction, packageState] state in
        switch state.action {
        case .install(.completed):
          refreshAction.send()
        case .uninstall(.completed):
          // Remove locally installed version before refresh occurs.
          if case var .loaded(packages) = packageState.value {
            if let index = packages.formulae.firstIndex(where: { $0.id == state.id }) {
              packages.formulae[index].installedVersion = nil
            } else if let index = packages.casks.firstIndex(where: { $0.id == state.id }) {
              packages.casks[index].installedVersion = nil
            }
            packageState.send(.loaded(packages))
          }

          refreshAction.send()
        default:
          break
        }
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
    refreshAction.send()
  }

  func install(id: Package.ID) {
    activityState.send(ActivityState(id: id, action: .install(.started)))
  }

  func uninstall(id: Package.ID) {
    activityState.send(ActivityState(id: id, action: .uninstall(.started)))
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
    refreshAction
      .prepend(())
      .map { [homebrew] in
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
          .compactMap { $0.id == packageID ? $0.action : nil }
          .scan(PackageDetail(package: package, activity: nil)) { detail, state in
            var detail = detail
            switch state {
            case .uninstall(.started):
              detail.activity = .uninstalling
            case .uninstall(.completed):
              detail.activity = nil
              detail.package.installedVersion = nil
            case .install(.started), .install(.completed):
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
