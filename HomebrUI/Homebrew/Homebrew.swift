import Foundation
import Combine

struct Homebrew {
  struct Configuration {
    var executablePath: String
  }

  private let commandQueue: HomebrewCommandQueue

  init(configuration: Configuration = .default) {
    self.commandQueue = HomebrewCommandQueue(configuration: configuration)
  }

  func list() -> AnyPublisher<HomebrewInfo, Error> {
    commandQueue.run(.list)
      .tryMap { result in
        guard result.status == 0 else {
          throw HomebrewError(status: result.status, output: result.standardError)
        }
        return try JSONDecoder().decode(HomebrewInfo.self, from: result.standardOutput)
      }
      .eraseToAnyPublisher()
  }

  func uninstallFormulae(name: String) -> AnyPublisher<String, Error> {
    commandQueue.run(.uninstall(name))
      .tryMap { result in
        guard result.status == 0 else {
          throw HomebrewError(status: result.status, output: result.standardError)
        }
        return String(decoding: result.standardOutput, as: UTF8.self)
      }
      .eraseToAnyPublisher()
  }
}

extension Homebrew.Configuration {
  static let `default` = Homebrew.Configuration(executablePath: "/usr/local/bin/brew")
}

private struct HomebrewError: LocalizedError {
  let status: Int
  let output: Data

  var errorDescription: String {
    "Exited with status \(status): \(String(decoding: output, as: UTF8.self))"
  }
}
