import Combine
import Foundation

class OperationRepository {
  private let accumulatedOperations = CurrentValueSubject<[HomebrewOperation], Never>([])

  private var cancellables = Set<AnyCancellable>()

  init(homebrew: Homebrew) {
    homebrew.operationPublisher
      .scan([HomebrewOperation.ID: HomebrewOperation]()) { operations, operation in
        var operations = operations
        operations[operation.id] = operation
        return operations
      }
      .map { operations in
        operations.values.sorted(by: { $0.started > $1.started })
      }
      .receive(on: DispatchQueue.main)
      .sink { [accumulatedOperations] operations in
        accumulatedOperations.send(operations)
      }
      .store(in: &cancellables)
  }

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
    cancellables.removeAll()
  }
}

extension OperationRepository {
  var operations: AnyPublisher<[HomebrewOperation], Never> {
    accumulatedOperations.eraseToAnyPublisher()
  }

  func status(for id: Package.ID) -> AnyPublisher<PackageStatus?, Never> {
    accumulatedOperations
      .map { operations in
        operations.compactMap { operation in
          guard operation.status.isRunning else {
            return nil
          }
          switch operation.command {
          case .install(let ids) where ids.contains(id):
            return .installing
          case .uninstall(let ids) where ids.contains(id):
            return .uninstalling
          case .upgrade(.only(let ids)) where ids.contains(id):
            return .updating
          default:
            return nil
          }
        }.first
      }
      .eraseToAnyPublisher()
  }
}

private extension HomebrewOperation.Status {
  var isRunning: Bool {
    switch self {
    case .queued, .running: return true
    case .completed, .cancelled: return false
    }
  }
}
