import Foundation

struct Package: Equatable {
  var name: String
  var version: String
}

extension Package: Identifiable {
  var id: String { name }
}
