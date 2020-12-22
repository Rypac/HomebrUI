import Foundation

enum HomebrewCommand {
  case list
  case info([HomebrewID])
  case search(String)
  case update
  case upgrade(HomebrewUpgradeStrategy)
  case install([HomebrewID])
  case uninstall([HomebrewID])
}

enum HomebrewUpgradeStrategy {
  case only([HomebrewID])
  case all
}

extension HomebrewCommand {
  var arguments: [String] {
    switch self {
    case .list:
      return ["info", "--json=v2", "--installed"]
    case .info(let formulae):
      return ["info", "--json=v2"] + formulae
    case .search(let query):
      return ["search", query]
    case .update:
      return ["update"]
    case .upgrade(.all):
      return ["upgrade"]
    case .upgrade(.only(let formulae)):
      return ["upgrade"] + formulae
    case .install(let formulae):
      return ["install"] + formulae
    case .uninstall(let formulae):
      return ["uninstall"] + formulae
    }
  }
}

private func +(_ arguments: [String], ids: [HomebrewID]) -> [String] {
  ids.reduce(into: arguments) { $0.append($1.rawValue) }
}
