import Combine
import Foundation

private let homebrewQueue: OperationQueue = {
  let queue = OperationQueue()
  queue.name = "Homebrew Command Queue"
  queue.maxConcurrentOperationCount = 1
  return queue
}()

struct HomebrewOperation: Identifiable {
  typealias ID = UUID

  enum Status {
    case queued
    case running
    case completed(ProcessResult)
    case cancelled
  }

  let id: ID
  let command: HomebrewCommand
  let status: Status
}

final class HomebrewQueue {
  private let operationSubject = CurrentValueSubject<HomebrewOperation?, Never>(nil)

  private let configuration: Homebrew.Configuration

  init(configuration: Homebrew.Configuration = .default) {
    self.configuration = configuration
  }

  deinit {
    homebrewQueue.cancelAllOperations()
  }

  @discardableResult
  func add(_ command: HomebrewCommand) -> HomebrewOperation.ID {
    let id = HomebrewOperation.ID()

    operationSubject.send(
      HomebrewOperation(id: id, command: command, status: .queued)
    )

    homebrewQueue.addOperation(
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
    if let process = homebrewQueue.operations.first(where: { ($0 as? ProcessOperation)?.id == id }) {
      process.cancel()
    }
  }
}

extension HomebrewQueue {
  var operation: AnyPublisher<HomebrewOperation, Never> {
    operationSubject
      .compactMap { $0 }
      .eraseToAnyPublisher()
  }

  func run(_ command: HomebrewCommand) -> AnyPublisher<ProcessResult, Error> {
    let id = add(command)
    return operationSubject
      .tryCompactMap { operation in
        guard let operation = operation, operation.id == id else {
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

private struct HomebrewCancellationError: Error {}
