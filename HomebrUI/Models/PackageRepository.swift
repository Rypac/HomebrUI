import Foundation
import Combine

class PackageRepository {
  private enum PackageState {
    case empty
    case loaded([Package])
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

    let refreshAction = actions
      .compactMap { action -> Void? in
        guard action == .refresh, self.refreshState.value == .idle else {
          return nil
        }
        return ()
      }

    refreshAction
      .flatMap {
        homebrew.list()
          .handleEvents(
            receiveSubscription: { sub in
              print("Refresh started")
              self.refreshState.send(.refreshing)
            },
            receiveCompletion: { completion in
              switch completion {
              case .failure(let error):
                print(error.localizedDescription)
              case .finished:
                print("Refresh completed")
              }
              self.refreshState.send(.idle)
            }
          )
          .compactMap { info in
            print(info)
            return info.formulae.compactMap { formulae in
              guard let installedPackage = formulae.installed.first, installedPackage.installedOnRequest else {
                return nil
              }
              return Package(
                name: formulae.name,
                version: installedPackage.version
              )
            }
          }
          .catch { error -> AnyPublisher<[Package], Never> in
            print(error.localizedDescription)
            return Just([]).eraseToAnyPublisher()
          }
      }
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { packages in
          self.packageState.send(.loaded(packages))
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
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            print(error.localizedDescription)
          case .finished:
            print("Uninstall completed")
          }
        },
        receiveValue: { output in
          print(output)
          self.refresh()
        }
      )
      .store(in: &cancellables)
  }
}

extension PackageRepository {
  var packages: AnyPublisher<[Package], Never> {
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
