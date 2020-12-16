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
    Process.runPublisher(
      for: URL(fileURLWithPath: configuration.executablePath),
      arguments: ["info", "--json=v2", "--installed"]
    ) { data in
      let info = try JSONDecoder().decode(HomebrewInfo.self, from: data)
      return info.formulae.compactMap { formulae in
        guard let installedPackage = formulae.installed.first, installedPackage.installedOnRequest else {
          return nil
        }
        return Package(
          name: formulae.name,
          version: installedPackage.version
        )
      }
    }
    .eraseToAnyPublisher()
  }
}

extension Homebrew.Configuration {
  static let `default` = Homebrew.Configuration(executablePath: "/usr/local/bin/brew")
}
