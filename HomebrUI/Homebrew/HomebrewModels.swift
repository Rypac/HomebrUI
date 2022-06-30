import Foundation

struct HomebrewID: Equatable, Hashable, Codable, RawRepresentable {
  let rawValue: String

  init(rawValue: String) {
    self.rawValue = rawValue
  }
}

extension HomebrewID: ExpressibleByStringLiteral {
  init(stringLiteral value: StringLiteralType) {
    rawValue = value
  }
}

extension HomebrewID: CustomStringConvertible {
  var description: String {
    String(describing: rawValue)
  }
}

struct HomebrewInfo: Equatable, Codable {
  var formulae: [Formulae]
  var casks: [Cask]
}

struct HomebrewSearchInfo: Equatable {
  var formulae: [HomebrewID]
  var casks: [HomebrewID]
}

struct Formulae: Equatable, Identifiable {
  let id: HomebrewID
  let name: String
  let oldName: String?
  let aliases: [String]
  let description: String
  let license: String?
  let homepage: URL
  let versions: FormulaeVersion
  let urls: [String: FormulaeURL]
  let revision: Int
  let versionScheme: Int
  let kegOnly: Bool
  let buildDependencies: [String]
  let dependencies: [String]
  let recommendedDependencies: [String]
  let optionalDependencies: [String]
  let pinned: Bool
  let outdated: Bool
  let deprecated: Bool
  let disabled: Bool
  let installed: [InstalledPackage]
}

struct FormulaeVersion: Equatable, Codable {
  let stable: String
  let head: String?
  let bottle: Bool
}

struct FormulaeURL: Equatable, Codable {
  let url: URL
  let tag: String?
  let revision: String?
}

struct InstalledPackage: Equatable {
  struct Dependency: Equatable {
    let name: String
    let version: String
  }

  let version: String
  let runtimeDependencies: [Dependency]
  let installedAsDependency: Bool
  let installedOnRequest: Bool
}

extension Formulae: Codable {
  enum CodingKeys: String, CodingKey {
    case id = "name"
    case name = "full_name"
    case oldName = "oldname"
    case aliases
    case description = "desc"
    case license
    case homepage
    case versions
    case urls
    case revision
    case versionScheme = "version_scheme"
    case kegOnly = "keg_only"
    case buildDependencies = "build_dependencies"
    case dependencies
    case recommendedDependencies = "recommended_dependencies"
    case optionalDependencies = "optional_dependencies"
    case pinned
    case outdated
    case deprecated
    case disabled
    case installed
  }
}

extension InstalledPackage: Codable {
  enum CodingKeys: String, CodingKey {
    case version
    case runtimeDependencies = "runtime_dependencies"
    case installedAsDependency = "installed_as_dependency"
    case installedOnRequest = "installed_on_request"
  }
}

extension InstalledPackage.Dependency: Codable {
  enum CodingKeys: String, CodingKey {
    case name = "full_name"
    case version
  }
}

struct Cask: Equatable, Identifiable {
  let id: HomebrewID
  let names: [String]
  let description: String?
  let homepage: URL
  let url: URL
  let appCast: URL?
  let version: String
  let sha256: String
  let autoUpdates: Bool?
}

extension Cask: Codable {
  enum CodingKeys: String, CodingKey {
    case id = "token"
    case names = "name"
    case description = "desc"
    case homepage
    case url
    case appCast = "appcast"
    case version
    case sha256
    case autoUpdates = "auto_updates"
  }
}
