import Combine
import Foundation

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

// Homebrew does not allow for concurrent running of commands so all operations
// must be queue and performed serially.
final class HomebrewOperationQueue {
  /// The serial queue for running Homebrew commands.
  private static let queue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "Homebrew Command Queue"
    queue.maxConcurrentOperationCount = 1
    return queue
  }()

  private let operationSubject = CurrentValueSubject<HomebrewOperation?, Never>(nil)

  private let configuration: HomebrewConfiguration

  init(configuration: HomebrewConfiguration = .default) {
    self.configuration = configuration
  }

  deinit {
    Self.queue.cancelAllOperations()
  }

  /// A messsage center style publisher which emits new Homebrew operations and status
  /// changes as they occur.
  var operationPublisher: AnyPublisher<HomebrewOperation, Never> {
    operationSubject
      .compactMap { $0 }
      .eraseToAnyPublisher()
  }

  /// Runs a Homebrew command and returns the result of running the command, optionally
  /// completing with an error if the operation is cancelled.
  func run(_ command: HomebrewCommand) -> AnyPublisher<ProcessResult, Error> {
    let id = enqueue(command)
    return operationSubject
      .tryCompactMap { operation in
        guard let operation = operation, operation.id == id else {
          return nil
        }
        switch operation.status {
        case .completed(let result): return result
        case .cancelled: throw HomebrewCancellationError(id: id)
        case .queued, .running: return nil
        }
      }
      .first()
      .eraseToAnyPublisher()
  }

  @discardableResult
  func enqueue(_ command: HomebrewCommand) -> HomebrewOperation.ID {
    let id = HomebrewOperation.ID()

    operationSubject.send(
      HomebrewOperation(id: id, command: command, status: .queued)
    )

    Self.queue.addOperation(
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
    if let process = Self.queue.operations.first(where: { ($0 as? ProcessOperation)?.id == id }) {
      process.cancel()
    }
  }
}

private struct HomebrewCancellationError: LocalizedError {
  let id: HomebrewOperation.ID

  var errorDescription: String {
    "Cancelled running command: \(id)"
  }
}
