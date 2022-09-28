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
    let group = DispatchGroup()

    let process = Process()
    process.executableURL = url
    process.arguments = arguments
    process.qualityOfService = qualityOfService

    let outputPipe = Pipe()
    let errorPipe = Pipe()

    process.standardOutput = outputPipe
    process.standardError = errorPipe

    var outputData = Data()
    var errorData = Data()

    group.enter()
    outputPipe.read { data in
      outputData.append(data)
    } onCompletion: {
      group.leave()
    }

    group.enter()
    errorPipe.read { data in
      errorData.append(data)
    } onCompletion: {
      group.leave()
    }

    group.enter()
    process.terminationHandler = { handle in
      handle.terminationHandler = nil
      group.leave()
    }

    try process.run()

    return await withTaskCancellationHandler {
      if process.isRunning {
        process.terminate()
      }
    } operation: {
      await withCheckedContinuation { continuation in
        group.notify(queue: processQueue) {
          continuation.resume(
            returning: ProcessResult(
              status: Int(process.terminationStatus),
              standardOutput: outputData,
              standardError: errorData
            )
          )
        }
      }
    }
  }

  private static let processQueue = DispatchQueue(label: "ProcessQueue", attributes: .concurrent)
}

extension Pipe {
  fileprivate func read(
    onDataAvailable: @escaping (Data) -> Void,
    onCompletion: @escaping () -> Void
  ) {
    fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      if !data.isEmpty {
        onDataAvailable(data)
      } else {
        handle.readabilityHandler = nil
        onCompletion()
      }
    }
  }
}
