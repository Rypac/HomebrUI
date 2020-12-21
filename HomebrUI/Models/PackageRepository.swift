import Combine
import Foundation

class PackageRepository {
  private enum PackageState {
    case empty
    case loaded(InstalledPackages)
  }

  private enum RefreshState {
    case idle
    case refreshing
  }

  private enum Action {
    case refresh
  }

  private let packageState = CurrentValueSubject<PackageState, Never>(.empty)
  private let refreshState = CurrentValueSubject<RefreshState, Never>(.idle)
  private let actions = PassthroughSubject<Action, Never>()
  private let homebrew: Homebrew

  private var cancellables = Set<AnyCancellable>()

  init(homebrew: Homebrew) {
    self.homebrew = homebrew

    actions
      .filter { $0 == .refresh }
      .map { _ in
        homebrew.installedPackages()
          .handleEvents(
            receiveSubscription: { _ in
              self.refreshState.send(.refreshing)
            },
            receiveCompletion: { _ in
              self.refreshState.send(.idle)
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
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { installedPackages in
          self.packageState.send(.loaded(installedPackages))
        }
      )
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
    homebrew.installFormulae(ids: [id])
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [actions] output in
          actions.send(.refresh)
        }
      )
      .store(in: &cancellables)
  }

  func uninstall(id: Package.ID) {
    homebrew.uninstallFormulae(ids: [id])
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [packageState, actions] _ in
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
        }
      )
      .store(in: &cancellables)
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

  func info(for packageID: Package.ID) -> AnyPublisher<Package, Error> {
    info(for: [packageID])
      .tryMap { packages in
        guard let package = packages.first(where: { $0.id == packageID }) else {
          throw PackageInfoError.missingPackage(packageID)
        }
        return package
      }
      .eraseToAnyPublisher()
  }

  func info(for packageIDs: [Package.ID]) -> AnyPublisher<[Package], Error> {
    homebrew.info(for: packageIDs)
      .tryMap { info in
        let fomulae = info.formulae.compactMap { formulae -> Package? in
          guard packageIDs.contains(formulae.id) else {
            return nil
          }
          return Package(formulae: formulae)
        }
        let casks = info.casks.compactMap { cask -> Package? in
          guard packageIDs.contains(cask.id) else {
            return nil
          }
          return Package(cask: cask)
        }

        let packages = fomulae + casks

        guard packages.count == packageIDs.count else {
          throw PackageInfoError.invalidPackageCount(
            expected: packageIDs.count,
            actual: packages.count
          )
        }

        return packages
      }
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
