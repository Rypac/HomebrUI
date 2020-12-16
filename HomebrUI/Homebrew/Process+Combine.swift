import Foundation
import Combine

struct ProcessError: Error {
  let status: Int
  let data: Data
}

extension ProcessError: LocalizedError {
  var errorDescription: String? {
    "Completed with status \(status): \(data)"
  }
}

extension Process {
  static func runPublisher(
    for url: URL,
    arguments: [String],
    qualityOfService: QualityOfService = .default,
    queue: DispatchQueue = .global(qos: .background)
  ) -> AnyPublisher<Data, ProcessError> {
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
            completion(.failure(ProcessError(status: Int(errno), data: Data())))
            return
          }
        }

        var collectedData = Data()

        channel.read(offset: 0, length: Int.max, queue: queue) { closed, dispatchData, error in
          if let data = dispatchData, !data.isEmpty {
            collectedData.append(contentsOf: data)
          }

          if closed {
            channel.close()

            if error == 0 {
              completion(.success(collectedData))
            } else {
              completion(.failure(ProcessError(status: Int(error), data: collectedData)))
            }
          }
        }

        task.launch()
      }
    }
    .eraseToAnyPublisher()
  }
}
