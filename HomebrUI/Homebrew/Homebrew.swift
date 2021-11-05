import Foundation
import Combine

struct Homebrew {
  private let queue: HomebrewOperationQueue

  init(configuration: HomebrewConfiguration = .default) {
    queue = HomebrewOperationQueue(configuration: configuration)
  }

  var operationPublisher: AnyPublisher<HomebrewOperation, Never> {
    queue.operationPublisher
  }

  func installedPackages() async throws -> HomebrewInfo {
    let result = try await queue.run(.list)

    guard result.status == 0 else {
      throw HomebrewError(processResult: result)
    }
    return try JSONDecoder().decode(HomebrewInfo.self, from: result.standardOutput)
  }

  func search(for query: String) async throws -> HomebrewSearchInfo {
    let result = try await queue.run(.search(query))

    guard result.status == 0 else {
      let errorMessage = String(decoding: result.standardError, as: UTF8.self)
      guard errorMessage.hasPrefix("Error: No formulae or casks found for") else {
        throw HomebrewError(processResult: result)
      }
      return HomebrewSearchInfo(formulae: [], casks: [])
    }

    enum SearchResult { case formulae, cask }
    var searchResult: SearchResult?

    return String(decoding: result.standardOutput, as: UTF8.self)
      .split(separator: "\n")
      .reduce(into: HomebrewSearchInfo(formulae: [], casks: [])) { search, line in
        switch line {
        case "==> Formulae":
          searchResult = .formulae
        case "==> Casks":
          searchResult = .cask
        case let line where !line.isEmpty:
          if searchResult == .formulae {
            search.formulae.append(HomebrewID(rawValue: String(line)))
          } else if searchResult == .cask {
            search.casks.append(HomebrewID(rawValue: String(line)))
          }
        default:
          break
        }
      }
  }

  func info(for packages: [HomebrewID]) async throws -> HomebrewInfo {
    if packages.isEmpty {
      return HomebrewInfo(formulae: [], casks: [])
    }

    let result = try await queue.run(.info(packages))

    guard result.status == 0 else {
      throw HomebrewError(processResult: result)
    }
    return try JSONDecoder().decode(HomebrewInfo.self, from: result.standardOutput)
  }

  func installFormulae(ids: [HomebrewID]) async throws -> String {
    let result = try await queue.run(.install(ids))

    guard result.status == 0 else {
      throw HomebrewError(processResult: result)
    }
    return String(decoding: result.standardOutput, as: UTF8.self)
  }

  func uninstallFormulae(ids: [HomebrewID]) async throws -> String {
    let result = try await queue.run(.uninstall(ids))

    guard result.status == 0 else {
      throw HomebrewError(processResult: result)
    }
    return String(decoding: result.standardOutput, as: UTF8.self)
  }
}

private struct HomebrewError: LocalizedError {
  let status: Int
  let output: Data

  var errorDescription: String {
    "Exited with status \(status): \(String(decoding: output, as: UTF8.self))"
  }
}

private extension HomebrewError {
  init(processResult result: ProcessResult) {
    self.init(
      status: result.status,
      output: result.standardError.isEmpty ? result.standardOutput : result.standardError
    )
  }
}
