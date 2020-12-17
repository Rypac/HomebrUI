import Foundation
import Combine

struct Homebrew {
  private let queue: HomebrewOperationQueue

  init(configuration: HomebrewConfiguration = .default) {
    self.queue = HomebrewOperationQueue(configuration: configuration)
  }

  func list() -> AnyPublisher<HomebrewInfo, Error> {
    queue.run(.list)
      .tryMap { result in
        guard result.status == 0 else {
          throw HomebrewError(status: result.status, output: result.standardError)
        }
        return try JSONDecoder().decode(HomebrewInfo.self, from: result.standardOutput)
      }
      .eraseToAnyPublisher()
  }

  func uninstallFormulae(name: String) -> AnyPublisher<String, Error> {
    queue.run(.uninstall(name))
      .tryMap { result in
        guard result.status == 0 else {
          throw HomebrewError(status: result.status, output: result.standardError)
        }
        return String(decoding: result.standardOutput, as: UTF8.self)
      }
      .eraseToAnyPublisher()
  }
}

extension Homebrew {
  var operation: AnyPublisher<HomebrewOperation, Never> {
    queue.operation
  }
}

private struct HomebrewError: LocalizedError {
  let status: Int
  let output: Data

  var errorDescription: String {
    "Exited with status \(status): \(String(decoding: output, as: UTF8.self))"
  }
}
