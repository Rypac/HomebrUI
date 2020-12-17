import Foundation

struct InstalledPackages {
  var formulae: [Package]
  var casks: [Package]
}

struct Package: Equatable {
  var name: String
  var version: String
}

extension Package: Identifiable {
  var id: String { name }
}
