import Foundation
import Combine

enum ProcessTaskError: Error {
  case failedToRun(reason: Error)
  case failedTransformingOutput(reason: Error)
  case terminatedWithoutCompletion
  case terminated(status: Int, output: String)
}

extension ProcessTaskError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case let .failedToRun(reason):
      return "Failed to run: \(reason.localizedDescription)"
    case let .failedTransformingOutput(reason):
      return "Failed to transform output: \(reason.localizedDescription)"
    case .terminatedWithoutCompletion:
      return "Terminated without completion"
    case let .terminated(status, output):
      return "Completed with status \(status): \(output)"
    }
  }
}

extension Process {
  static func runPublisher<Output>(
    for url: URL,
    arguments: [String],
    qualityOfService: QualityOfService = .default,
    queue: DispatchQueue = .global(qos: .background),
    transform: @escaping (Data) throws -> Output
  ) -> AnyPublisher<Output, ProcessTaskError> {
    Deferred {
      Future { completion in
        let task = Process()
        task.executableURL = url
        task.arguments = arguments
        task.qualityOfService = qualityOfService

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        let channel = DispatchIO(type: .stream, fileDescriptor: outputPipe.fileHandleForReading.fileDescriptor, queue: queue) { errno in
          guard errno == 0 else {
            fatalError("Error reading from channel")
          }
        }

        var collectedData = Data()

        channel.read(offset: 0, length: Int.max, queue: queue) { closed, dispatchData, error in
          if let data = dispatchData, !data.isEmpty {
            collectedData.append(contentsOf: data)
          }

          if closed {
            channel.close()

            do {
              completion(.success(try transform(collectedData)))
            } catch {
              completion(.failure(.failedTransformingOutput(reason: error)))
            }
          }
        }

        task.launch()
      }
    }
    .eraseToAnyPublisher()
  }
}
