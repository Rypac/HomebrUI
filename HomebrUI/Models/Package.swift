import Foundation

struct Package: Identifiable, Equatable {
  let id: HomebrewID
  var name: String
  var description: String?
  var homepage: URL
  var installedVersion: String?
  var latestVersion: String
}

enum PackageActivity {
  case installing
  case updating
  case uninstalling
}

@dynamicMemberLookup
struct PackageDetail: Identifiable {
  var id: Package.ID { package.id }
  var package: Package
  var activity: PackageActivity?

  var isInstalled: Bool { package.installedVersion != nil }

  subscript<Property>(dynamicMember keyPath: WritableKeyPath<Package, Property>) -> Property {
    get { package[keyPath: keyPath] }
    set { package[keyPath: keyPath] = newValue }
  }
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
