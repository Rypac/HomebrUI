import Combine
import Foundation

struct ProcessResult: Equatable {
  let status: Int
  let standardOutput: Data
  let standardError: Data
}

extension Process {
  static func run(
    for url: URL,
    arguments: [String] = [],
    qualityOfService: QualityOfService = .default
  ) async throws -> ProcessResult {
    let queue = OperationQueue()
    queue.name = "Process Queue"
    queue.maxConcurrentOperationCount = 3
    queue.qualityOfService = qualityOfService

    let process = Process()
    process.executableURL = url
    process.arguments = arguments
    process.qualityOfService = qualityOfService

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        do {
          let outputPipe = Pipe()
          let errorPipe = Pipe()

          process.standardOutput = outputPipe
          process.standardError = errorPipe

          try process.run()

          var outputData = Data()
          var errorData = Data()

          queue.addOperation {
            outputPipe.read(into: &outputData)
          }
          queue.addOperation {
            errorPipe.read(into: &errorData)
          }
          queue.addOperation {
            process.waitUntilExit()
          }

          queue.addBarrierBlock {
            continuation.resume(
              returning: ProcessResult(
                status: Int(process.terminationStatus),
                standardOutput: outputData,
                standardError: errorData
              )
            )
          }
        } catch {
          continuation.resume(throwing: error)
        }
      }
    } onCancel: {
      if process.isRunning {
        process.terminate()
      }
      queue.cancelAllOperations()
    }
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
