import Foundation
import Combine

enum ProcessTaskError: Error {
  case failedToRun(reason: Error)
  case terminatedWithoutCompletion
  case terminated(status: Int, output: String)
}

extension ProcessTaskError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case let .failedToRun(reason):
      return "Failed to run: \(reason.localizedDescription)"
    case .terminatedWithoutCompletion:
      return "Terminated without completion"
    case let .terminated(status, output):
      return "Completed with status \(status): \(output)"
    }
  }
}

extension Process {
  static func runPublisher(for url: URL, arguments: [String]) -> AnyPublisher<String, ProcessTaskError> {
    Deferred {
      Future<String, ProcessTaskError> { completion in
        let task = Process()
        task.executableURL = url
        task.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        task.terminationHandler = { process in
          guard !process.isRunning else {
            completion(.failure(.terminatedWithoutCompletion))
            return
          }

          let status = Int(process.terminationStatus)

          if status == 0 {
            completion(.success(outputPipe.readOutput()))
          } else {
            completion(.failure(.terminated(status: status, output: errorPipe.readOutput())))
          }
        }

        do {
          try task.run()
        } catch {
          completion(.failure(.failedToRun(reason: error)))
        }
      }
    }
    .eraseToAnyPublisher()
  }
}

private extension Pipe {
  func readOutput() -> String {
    String(decoding: fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
  }
}
