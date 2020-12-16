import Foundation
import Combine

struct Homebrew {
  struct Configuration {
    var executablePath: String
  }

  private let configuration: Configuration

  init(configuration: Configuration = .default) {
    self.configuration = configuration
  }

  func list() -> AnyPublisher<HomebrewInfo, Error> {
    Process.runPublisher(
      for: URL(fileURLWithPath: configuration.executablePath),
      arguments: ["info", "--json=v2", "--installed"]
    )
    .tryMap { result in
      guard result.status == 0 else {
        throw HomebrewError(status: result.status, output: result.standardError)
      }
      return try JSONDecoder().decode(HomebrewInfo.self, from: result.standardOutput)
    }
    .catch { error -> AnyPublisher<HomebrewInfo, Error> in
      print(error.localizedDescription)
      return Just(HomebrewInfo(formulae: [], casks: []))
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
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
