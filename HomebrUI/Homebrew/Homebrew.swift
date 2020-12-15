import Foundation
import Combine

struct Package: Equatable {
  var name: String
}

extension Package: Identifiable {
  var id: String { name }
}

struct Homebrew {
  struct Configuration {
    var executablePath: String
  }

  private let configuration: Configuration

  init(configuration: Configuration = .default) {
    self.configuration = configuration
  }

  func list() -> AnyPublisher<[Package], ProcessTaskError> {
    Process.runPublisher(for: URL(fileURLWithPath: configuration.executablePath), arguments: ["list"])
      .map { output in
        output.split(separator: "\n").map { Package(name: String($0)) }
      }
      .eraseToAnyPublisher()
  }
}

extension Homebrew.Configuration {
  static let `default` = Homebrew.Configuration(executablePath: "/usr/local/bin/brew")
}
