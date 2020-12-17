import Foundation

final class ProcessOperation: AsyncOperation, Identifiable {
  typealias ID = UUID

  let id: ID
  private let url: URL
  private let arguments: [String]
  private let startHandler: () -> Void
  private let cancellationHandler: () -> Void
  private let completionHandler: (ProcessResult) -> Void

  private var processHandle: ProcessHandle?

  init(
    id: ID,
    url: URL,
    arguments: [String] = [],
    qualityOfService: QualityOfService = .default,
    startHandler: @escaping () -> Void,
    cancellationHandler: @escaping () -> Void,
    completionHandler: @escaping (ProcessResult) -> Void
  ) {
    self.id = id
    self.url = url
    self.arguments = arguments
    self.startHandler = startHandler
    self.cancellationHandler = cancellationHandler
    self.completionHandler = completionHandler
    super.init()
    self.qualityOfService = qualityOfService
  }

  override func main() {
    startHandler()

    processHandle = try? Process.run(
      for: url,
      arguments: arguments,
      qualityOfService: qualityOfService
    ) { [weak self] result in
      self?.completionHandler(result)
      self?.finish()
    }
  }

  override func cancel() {
    processHandle?.cancel()
    cancellationHandler()
    super.cancel()
  }
}
