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

  init(homebrew: Homebrew = Homebrew()) {
    self.homebrew = homebrew

    actions
      .filter { $0 == .refresh }
      .map { _ in
        homebrew.listInstalledPackages()
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
  var operationPublisher: AnyPublisher<HomebrewOperation, Never> {
    homebrew.operationPublisher
  }

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
}
