import Combine
import Foundation

struct ProcessHandle: Identifiable {
  let id: Int
  let cancel: () -> Void
}

struct ProcessResult: Equatable {
  let status: Int
  let standardOutput: Data
  let standardError: Data
}

extension Process {
  static func runPublisher(
    for url: URL,
    arguments: [String] = [],
    qualityOfService: QualityOfService = .default,
    queue: DispatchQueue = .global(qos: .userInitiated)
  ) -> AnyPublisher<ProcessResult, Error> {
    Deferred {
      Future { completion in
        do {
          _ = try run(for: url, arguments: arguments, qualityOfService: qualityOfService) { result in
            completion(.success(result))
          }
        } catch {
          completion(.failure(error))
        }
      }
    }
    .eraseToAnyPublisher()
  }
}

extension Process {
  static func run(
    for url: URL,
    arguments: [String] = [],
    qualityOfService: QualityOfService = .default,
    handler: @escaping (ProcessResult) -> Void
  ) throws -> ProcessHandle {
    let task = Process()
    task.executableURL = url
    task.arguments = arguments
    task.qualityOfService = qualityOfService

    let outputPipe = Pipe()
    let errorPipe = Pipe()

    task.standardOutput = outputPipe
    task.standardError = errorPipe

    try task.run()

    var outputData = Data()
    var errorData = Data()

    processQueue.addOperation {
      outputPipe.read(into: &outputData)
    }
    processQueue.addOperation {
      errorPipe.read(into: &errorData)
    }
    processQueue.addOperation {
      task.waitUntilExit()
    }

    processQueue.addBarrierBlock {
      handler(
        ProcessResult(
          status: Int(task.terminationStatus),
          standardOutput: outputData,
          standardError: errorData
        )
      )
    }

    return ProcessHandle(
      id: Int(task.processIdentifier),
      cancel: task.terminate
    )
  }

  private static let processQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "Process Queue"
    queue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount
    return queue
  }()
}

private extension Pipe {
  func read(into buffer: inout Data) {
    var availableData = Data()
    repeat {
      availableData = fileHandleForReading.availableData
      buffer.append(availableData)
    } while !availableData.isEmpty
  }
}
