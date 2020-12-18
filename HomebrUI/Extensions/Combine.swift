import Combine

extension AnyPublisher {
  static func just(_ value: Output) -> Self {
    Just(value)
      .setFailureType(to: Failure.self)
      .eraseToAnyPublisher()
  }

  static var empty: Self {
    Empty(completeImmediately: true)
      .eraseToAnyPublisher()
  }

  static var never: Self {
    Empty(completeImmediately: false)
      .eraseToAnyPublisher()
  }
}
