import Foundation
import Combine

struct Package: Equatable {
  var name: String
  var version: String
}

extension Package: Identifiable {
  var id: String { name }
}

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

  private var cancellable: AnyCancellable?

  init(homebrew: Homebrew = Homebrew()) {
    let refreshAction = actions
      .compactMap { action -> Void? in
        guard action == .refresh, self.refreshState.value == .idle else {
          return nil
        }
        return ()
      }

    cancellable = refreshAction
      .flatMap {
        homebrew.list()
          .handleEvents(
            receiveSubscription: { _ in self.refreshState.send(.refreshing) },
            receiveCompletion: { _ in self.refreshState.send(.idle) }
          )
          .compactMap { info in
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
      }
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { packages in
          self.packageState.send(.loaded(packages))
        }
      )
  }

  deinit {
    cancellable?.cancel()
  }

  func refresh() {
    actions.send(.refresh)
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
