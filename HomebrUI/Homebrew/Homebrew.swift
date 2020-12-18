import Foundation
import Combine

struct Homebrew {
  private let queue: HomebrewOperationQueue

  init(configuration: HomebrewConfiguration = .default) {
    self.queue = HomebrewOperationQueue(configuration: configuration)
  }

  var operationPublisher: AnyPublisher<HomebrewOperation, Never> {
    queue.operationPublisher
  }

  func installedPackages() -> AnyPublisher<HomebrewInfo, Error> {
    queue.run(.list)
      .tryMap { result in
        guard result.status == 0 else {
          throw HomebrewError(processResult: result)
        }
        return try JSONDecoder().decode(HomebrewInfo.self, from: result.standardOutput)
      }
      .eraseToAnyPublisher()
  }

  func search(for query: String) -> AnyPublisher<[HomebrewID], Error> {
    queue.run(.search(query))
      .tryMap { result in
        guard result.status == 0 else {
          let errorMessage = String(decoding: result.standardError, as: UTF8.self)
          guard errorMessage.hasPrefix("Error: No formulae or casks found for") else {
            throw HomebrewError(processResult: result)
          }
          return []
        }

        return String(decoding: result.standardOutput, as: UTF8.self)
          .split(separator: "\n")
          .compactMap { line in
            // Ignore any empty lines and dividers between Formulae and Casks
            if line.isEmpty || line.starts(with: "==>") {
              return nil
            }
            return HomebrewID(rawValue: String(line))
          }
      }
      .eraseToAnyPublisher()
  }

  func info(for packages: [HomebrewID]) -> AnyPublisher<HomebrewInfo, Error> {
    queue.run(.info(packages.map(\.rawValue)))
      .tryMap { result in
        guard result.status == 0 else {
          throw HomebrewError(processResult: result)
        }
        return try JSONDecoder().decode(HomebrewInfo.self, from: result.standardOutput)
      }
      .eraseToAnyPublisher()
  }

  func uninstallFormulae(id: HomebrewID) -> AnyPublisher<String, Error> {
    queue.run(.uninstall(id.rawValue))
      .tryMap { result in
        guard result.status == 0 else {
          throw HomebrewError(processResult: result)
        }
        return String(decoding: result.standardOutput, as: UTF8.self)
      }
      .eraseToAnyPublisher()
  }
}

private struct HomebrewError: LocalizedError {
  let status: Int
  let output: Data

  var errorDescription: String {
    "Exited with status \(status): \(String(decoding: output, as: UTF8.self))"
  }
}

private extension HomebrewError {
  init(processResult result: ProcessResult) {
    self.init(
      status: result.status,
      output: result.standardError.isEmpty ? result.standardOutput : result.standardError
    )
  }
}
