import Combine
import Foundation

typealias CommandID = UUID

private let queue: OperationQueue = {
  let queue = OperationQueue()
  queue.name = "Homebrew Command Queue"
  queue.maxConcurrentOperationCount = 1
  return queue
}()

final class HomebrewQueue {
  private let operationSubject = PassthroughSubject<HomebrewOperation, Never>()
  private let allOperationsSubject = CurrentValueSubject<[HomebrewOperation], Never>([])

  private let configuration: Homebrew.Configuration
  private var cancellable: AnyCancellable?

  init(configuration: Homebrew.Configuration = .default) {
    self.configuration = configuration

    cancellable = operationSubject
      .scan([]) { operations, operation in
        var newOperations = operations
        if let index = newOperations.firstIndex(where: { $0.id == operation.id }) {
          newOperations[index] = operation
        } else {
          newOperations.append(operation)
        }
        return newOperations
      }
      .sink { [allOperationsSubject] operations in
        allOperationsSubject.send(operations)
      }
  }

  deinit {
    queue.cancelAllOperations()
    cancellable?.cancel()
    cancellable = nil
  }

  @discardableResult
  func add(_ command: HomebrewCommand) -> HomebrewOperation.ID {
    let id = HomebrewOperation.ID()

    operationSubject.send(
      HomebrewOperation(id: id, command: command, status: .queued)
    )

    queue.addOperation(
      ProcessOperation(
        id: id,
        url: URL(fileURLWithPath: configuration.executablePath),
        arguments: command.arguments,
        startHandler: { [operationSubject] in
          operationSubject.send(
            HomebrewOperation(id: id, command: command, status: .running)
          )
        },
        cancellationHandler: { [operationSubject] in
          operationSubject.send(
            HomebrewOperation(id: id, command: command, status: .cancelled)
          )
        },
        completionHandler: {  [operationSubject] result in
          operationSubject.send(
            HomebrewOperation(id: id, command: command, status: .completed(result))
          )
        }
      )
    )

    return id
  }

  func cancel(id: HomebrewOperation.ID) {
    if let process = queue.operations.first(where: { ($0 as? ProcessOperation)?.id == id }) {
      process.cancel()
    }
  }
}

extension HomebrewQueue {
  var operations: AnyPublisher<[HomebrewOperation], Never> {
    allOperationsSubject.eraseToAnyPublisher()
  }

  func run(_ command: HomebrewCommand) -> AnyPublisher<ProcessResult, Error> {
    let id = add(command)
    return allOperationsSubject
      .tryCompactMap { operations in
        guard let operation = operations.first(where: { $0.id == id }) else {
          return nil
        }
        switch operation.status {
        case .completed(let result): return result
        case .cancelled: throw HomebrewCancellationError()
        case .queued, .running: return nil
        }
      }
      .first()
      .eraseToAnyPublisher()
  }
}

struct HomebrewCancellationError: Error {}

struct HomebrewOperation: Identifiable {
  typealias ID = UUID
  typealias Command = HomebrewCommand

  enum Status {
    case queued
    case running
    case completed(ProcessResult)
    case cancelled
  }

  let id: ID
  let command: Command
  let status: Status
}
