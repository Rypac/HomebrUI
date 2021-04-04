import Combine
import Foundation

final class OperationRepository {
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
}
