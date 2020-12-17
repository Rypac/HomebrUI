import Foundation

/// An asynchronous `Operation` with proper multi-threading and KVO support.
///
/// Implementation from: https://www.avanderlee.com/swift/asynchronous-operations/
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
