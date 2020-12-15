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

  func list() -> AnyPublisher<String, ProcessTaskError> {
    Process.runPublisher(for: URL(fileURLWithPath: configuration.executablePath), arguments: ["list"])
  }
}

extension Homebrew.Configuration {
  static let `default` = Homebrew.Configuration(executablePath: "/usr/local/bin/brew")
}
