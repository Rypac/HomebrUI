import Combine
import Foundation

struct ProcessResult {
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
        queue.async {
          do {
            let result = try run(for: url, arguments: arguments, qualityOfService: qualityOfService)
            completion(.success(result))
          } catch {
            completion(.failure(error))
          }
        }
      }
    }
    .eraseToAnyPublisher()
  }

  private static let outputQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = String("output")
    queue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount
    return queue
  }()

  static func run(
    for url: URL,
    arguments: [String] = [],
    qualityOfService: QualityOfService = .default
  ) throws -> ProcessResult {
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

    outputQueue.addOperation {
      outputPipe.read(into: &outputData)
    }
    outputQueue.addOperation {
      errorPipe.read(into: &errorData)
    }

    outputQueue.waitUntilAllOperationsAreFinished()

    task.waitUntilExit()

    return ProcessResult(
      status: Int(task.terminationStatus),
      standardOutput: outputData,
      standardError: errorData
    )
  }
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
