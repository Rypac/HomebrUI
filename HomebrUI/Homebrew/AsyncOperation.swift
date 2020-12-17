import Foundation

open class AsyncOperation: Operation {
  private let lockQueue = DispatchQueue(label: "com.swiftlee.asyncoperation", attributes: .concurrent)

  open override var isAsynchronous: Bool {
    true
  }

  private var _isExecuting: Bool = false
  open override private(set) var isExecuting: Bool {
    get {
      lockQueue.sync {
        _isExecuting
      }
    }
    set {
      willChangeValue(forKey: "isExecuting")
      lockQueue.sync(flags: [.barrier]) {
        _isExecuting = newValue
      }
      didChangeValue(forKey: "isExecuting")
    }
  }

  private var _isFinished: Bool = false
  open override private(set) var isFinished: Bool {
    get {
      lockQueue.sync {
        _isFinished
      }
    }
    set {
      willChangeValue(forKey: "isFinished")
      lockQueue.sync(flags: [.barrier]) {
        _isFinished = newValue
      }
      didChangeValue(forKey: "isFinished")
    }
  }

  open override func start() {
    guard !isCancelled else {
      finish()
      return
    }

    isFinished = false
    isExecuting = true
    main()
  }

  open override func main() {
    fatalError("Subclasses must implement `main` without overriding super.")
  }

  func finish() {
    isExecuting = false
    isFinished = true
  }
}

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
