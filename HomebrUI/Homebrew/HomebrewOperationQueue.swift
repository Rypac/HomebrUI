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
  let started: Date
  var status: Status
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
  private let now: () -> Date

  init(configuration: HomebrewConfiguration = .default, now: @escaping () -> Date = Date.init) {
    self.configuration = configuration
    self.now = now
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
      .handleEvents(
        receiveCancel: { [weak self] in
          self?.cancel(id: id)
        }
      )
      .eraseToAnyPublisher()
  }

  @discardableResult
  func enqueue(_ command: HomebrewCommand) -> HomebrewOperation.ID {
    let id = HomebrewOperation.ID()
    let operation = HomebrewOperation(id: id, command: command, started: now(), status: .queued)

    operationSubject.send(operation)

    Self.queue.addOperation(
      ProcessOperation(
        id: id,
        url: URL(fileURLWithPath: configuration.executablePath),
        arguments: command.arguments,
        startHandler: { [operationSubject] in
          var operation = operation
          operation.status = .running
          operationSubject.send(operation)
        },
        cancellationHandler: { [operationSubject] in
          var operation = operation
          operation.status = .cancelled
          operationSubject.send(operation)
        },
        completionHandler: {  [operationSubject] result in
          var operation = operation
          operation.status = .completed(result)
          operationSubject.send(operation)
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
