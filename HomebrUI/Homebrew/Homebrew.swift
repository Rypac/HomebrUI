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

  func list() -> AnyPublisher<HomebrewInfo, ProcessTaskError> {
    Process.runPublisher(
      for: URL(fileURLWithPath: configuration.executablePath),
      arguments: ["info", "--json=v2", "--installed"]
    ) { data in
      try JSONDecoder().decode(HomebrewInfo.self, from: data)
    }
    .eraseToAnyPublisher()
  }
}

extension Homebrew.Configuration {
  static let `default` = Homebrew.Configuration(executablePath: "/usr/local/bin/brew")
}
