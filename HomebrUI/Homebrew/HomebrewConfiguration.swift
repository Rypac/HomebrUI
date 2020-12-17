import Foundation

struct HomebrewConfiguration {
  var executablePath: String
}

extension HomebrewConfiguration {
  static let `default` = Self(executablePath: "/usr/local/bin/brew")
}
