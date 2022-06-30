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

extension Publisher {
  /// Transforms all elements from the upstream publisher with a provided
  /// async closure.
  ///
  /// - Parameter transform: A closure that takes one element as its parameter
  ///   and asynchronously returns a new element.
  ///
  /// - Returns: A publisher that uses the provided closure to map elements
  ///   from the upstream publisher to new elements that it then publishes.
  func asyncMap<T>(
    _ transform: @escaping (Output) async -> T
  ) -> Publishers.FlatMap<Future<T, Never>, Self> {
    flatMap { value in
      Future { promise in
        Task {
          promise(.success(await transform(value)))
        }
      }
    }
  }

  /// Transforms all elements from the upstream publisher with a provided
  /// error-throwing async closure.
  ///
  /// - Parameter transform: A closure that takes one element as its parameter
  ///   and asynchronously returns a new element. If the closure throws an error,
  ///   the publisher fails with the thrown error.
  ///
  /// - Returns: A publisher that uses the provided closure to map elements
  ///   from the upstream publisher to new elements that it then publishes.
  func asyncTryMap<T>(
    _ transform: @escaping (Output) async throws -> T
  ) -> Publishers.FlatMap<Future<T, Error>, Self> {
    flatMap { value in
      Future { promise in
        Task {
          do {
            promise(.success(try await transform(value)))
          } catch {
            promise(.failure(error))
          }
        }
      }
    }
  }

  /// Transforms all elements from the upstream publisher with a provided
  /// error-throwing async closure.
  ///
  /// - Parameter transform: A closure that takes one element as its parameter
  ///   and asynchronously returns a new element. If the closure throws an error,
  ///   the publisher fails with the thrown error.
  ///
  /// - Returns: A publisher that uses the provided closure to map elements
  ///   from the upstream publisher to new elements that it then publishes.
  func asyncTryMap<T>(
    _ transform: @escaping (Output) async throws -> T
  ) -> Publishers.FlatMap<Future<T, Error>, Publishers.SetFailureType<Self, Error>> {
    flatMap { value in
      Future { promise in
        Task {
          do {
            promise(.success(try await transform(value)))
          } catch {
            promise(.failure(error))
          }
        }
      }
    }
  }
}
