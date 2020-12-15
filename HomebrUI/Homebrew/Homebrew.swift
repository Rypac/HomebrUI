import Foundation
import Combine

struct Package: Equatable {
  var name: String
  var version: String
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
    Process.runPublisher(for: URL(fileURLWithPath: configuration.executablePath), arguments: ["list", "--versions"])
      .map { output in
        output.split(separator: "\n").map { nameAndVersion in
          let splitNameAndVersion = nameAndVersion.split(separator: " ")
          if splitNameAndVersion.count == 2 {
            return Package(name: String(splitNameAndVersion[0]), version: String(splitNameAndVersion[1]))
          } else {
            return Package(name: String(nameAndVersion), version: "")
          }
        }
      }
      .eraseToAnyPublisher()
  }
}

extension Homebrew.Configuration {
  static let `default` = Homebrew.Configuration(executablePath: "/usr/local/bin/brew")
}
