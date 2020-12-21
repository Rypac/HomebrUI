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
              formulae: info.formulae.compactMap(Package.init(formulae:)),
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

  func uninstall(_ package: Package) {
    homebrew.uninstallFormulae(ids: [package.id])
      .receive(on: DispatchQueue.main)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [actions] output in
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
        let fomulae = info.formulae
          .filter { packageIDs.contains($0.id) }
          .map { formulae in
            Package(
              id: formulae.id,
              name: formulae.name,
              version: formulae.versions.stable,
              description: formulae.description,
              homepage: formulae.homepage
            )
          }
        let casks = info.casks
          .filter { packageIDs.contains($0.id) }
          .map { cask in
            Package(
              id: cask.id,
              name: cask.names.first ?? cask.id.rawValue,
              version: cask.version,
              description: cask.description,
              homepage: cask.homepage
            )
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
