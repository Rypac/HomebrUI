import Foundation

enum HomebrewCommand {
  case list
  case info(String)
  case search(String)
  case update
  case upgrade(HomebrewUpgradeStrategy)
  case uninstall(String)
}

enum HomebrewUpgradeStrategy {
  case only(String)
  case all
}

extension HomebrewCommand {
  var arguments: [String] {
    switch self {
    case .list:
      return ["info", "--json=v2", "--installed"]
    case .info(let formulae):
      return ["info", "--json=v2", formulae]
    case .search(let query):
      return ["search", query]
    case .update:
      return ["update"]
    case .upgrade(.all):
      return ["upgrade"]
    case .upgrade(.only(let formulae)):
      return ["upgrade", formulae]
    case .uninstall(let formulae):
      return ["uninstall", formulae]
    }
  }
}
