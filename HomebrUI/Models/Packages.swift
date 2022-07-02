import Foundation

struct Packages {
  var formulae: [Package]
  var casks: [Package]
}

extension Packages {
  var count: Int { formulae.count + casks.count }
  var isEmpty: Bool { formulae.isEmpty && casks.isEmpty }
  var hasFormulae: Bool { !formulae.isEmpty }
  var hasCasks: Bool { !casks.isEmpty }
}

extension Packages {
  subscript(id: Package.ID) -> Package? {
    formulae.first(where: { $0.id == id }) ?? casks.first(where: { $0.id == id })
  }
}
