import Foundation

struct Package: Identifiable, Equatable {
  typealias ID = HomebrewID

  let id: ID
  var name: String
  var description: String?
  var homepage: URL
  var installedVersion: String?
  var latestVersion: String
}

extension Package {
  var isInstalled: Bool { installedVersion != nil }
}

extension Package {
  init(formulae: Formulae) {
    let installedVersion: String?
    if let installed = formulae.installed.first, installed.installedOnRequest {
      installedVersion = installed.version
    } else {
      installedVersion = nil
    }

    self.init(
      id: formulae.id,
      name: formulae.name,
      description: formulae.description,
      homepage: formulae.homepage,
      installedVersion: installedVersion,
      latestVersion: formulae.versions.stable
    )
  }

  init(cask: Cask) {
    self.init(
      id: cask.id,
      name: cask.names.first ?? cask.id.rawValue,
      description: cask.description,
      homepage: cask.homepage,
      installedVersion: cask.version,
      latestVersion: cask.version
    )
  }
}
