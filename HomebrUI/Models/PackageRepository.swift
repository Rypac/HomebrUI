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
          .compactMap { info in
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
    homebrew.uninstallFormulae(name: package.id)
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
      .compactMap {
        guard case let .loaded(packages) = $0 else {
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

  func searchForPackage(withName query: String) -> AnyPublisher<[String], Error> {
    homebrew.search(for: query)
  }

  func info(for packageName: String) -> AnyPublisher<Package, Error> {
    info(for: [packageName])
      .tryMap { packages in
        guard let package = packages.first(where: { $0.id == packageName }) else {
          throw PackageInfoError.missingPackage(packageName)
        }
        return package
      }
      .eraseToAnyPublisher()
  }

  func info(for packageNames: [String]) -> AnyPublisher<[Package], Error> {
    homebrew.info(for: packageNames)
      .tryMap { info in
        let fomulae = info.formulae
          .filter { packageNames.contains($0.name) }
          .map { formulae in
            Package(
              id: formulae.name,
              name: formulae.fullName,
              version: formulae.versions.stable,
              description: formulae.description,
              homepage: formulae.homepage
            )
          }
        let casks = info.casks
          .filter { packageNames.contains($0.token) }
          .map { cask in
            Package(
              id: cask.token,
              name: cask.name.first ?? cask.token,
              version: cask.version,
              description: cask.description,
              homepage: cask.homepage
            )
          }

        let packages = fomulae + casks

        guard packages.count == packageNames.count else {
          throw PackageInfoError.invalidPackageCount(
            expected: packageNames.count,
            actual: packages.count
          )
        }

        return packages
      }
      .eraseToAnyPublisher()
  }
}

private enum PackageInfoError: LocalizedError {
  case missingPackage(String)
  case invalidPackageCount(expected: Int, actual: Int)

  var errorDescription: String {
    switch self {
    case let .missingPackage(name):
      return "Missing package \"\(name)\""
    case let .invalidPackageCount(expected, actual):
      return "Expected \(expected) packages but received \(actual)"
    }
  }
}
