import Foundation

struct InstalledPackages {
  var formulae: [Package]
  var casks: [Package]
}

struct Package: Identifiable, Equatable {
  typealias ID = HomebrewID

  let id: ID
  var name: String
  var version: String
  var description: String?
  var homepage: URL
}

extension Package {
  init?(formulae: Formulae) {
    guard let installed = formulae.installed.first, installed.installedOnRequest else {
      return nil
    }

    self.init(
      id: formulae.id,
      name: formulae.name,
      version: installed.version,
      description: formulae.description,
      homepage: formulae.homepage
    )
  }

  init(cask: Cask) {
    self.init(
      id: cask.id,
      name: cask.names.first ?? cask.id.rawValue,
      version: cask.version,
      description: cask.description,
      homepage: cask.homepage
    )
  }
}
