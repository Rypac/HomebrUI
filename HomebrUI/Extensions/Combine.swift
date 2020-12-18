import Combine

extension AnyPublisher where Failure == Never {
  static func just(_ value: Output) -> AnyPublisher<Output, Never> {
    Just(value)
      .setFailureType(to: Never.self)
      .eraseToAnyPublisher()
  }
}
