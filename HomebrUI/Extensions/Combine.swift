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
  public func asyncMap<T>(
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

  public func asyncTryMap<T>(
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

  public func asyncTryMap<T>(
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
