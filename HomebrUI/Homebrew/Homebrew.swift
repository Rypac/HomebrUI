import Foundation
import Combine

struct Homebrew {
  private let queue: HomebrewOperationQueue

  init(configuration: HomebrewConfiguration = .default) {
    queue = HomebrewOperationQueue(configuration: configuration)
  }

  var operationPublisher: some Publisher<HomebrewOperation, Never> {
    queue.operationPublisher
  }

  func installedPackages() -> some Publisher<HomebrewInfo, Error> {
    queue.run(.list)
      .tryMap { result in
        guard result.status == 0 else {
          throw HomebrewError(processResult: result)
        }
        return try JSONDecoder().decode(HomebrewInfo.self, from: result.standardOutput)
      }
  }

  func search(for query: String) -> some Publisher<HomebrewSearchInfo, Error> {
    queue.run(.search(query))
      .tryMap { result in
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
  }

  func info(for packages: [HomebrewID]) -> AnyPublisher<HomebrewInfo, Error> {
    if packages.isEmpty {
      return .just(HomebrewInfo(formulae: [], casks: []))
    }

    return queue.run(.info(packages))
      .tryMap { result in
        guard result.status == 0 else {
          throw HomebrewError(processResult: result)
        }
        return try JSONDecoder().decode(HomebrewInfo.self, from: result.standardOutput)
      }
      .eraseToAnyPublisher()
  }

  func installFormulae(ids: [HomebrewID]) -> some Publisher<String, Error> {
    queue.run(.install(ids))
      .tryMap { result in
        guard result.status == 0 else {
          throw HomebrewError(processResult: result)
        }
        return String(decoding: result.standardOutput, as: UTF8.self)
      }
  }

  func uninstallFormulae(ids: [HomebrewID]) -> some Publisher<String, Error> {
    queue.run(.uninstall(ids))
      .tryMap { result in
        guard result.status == 0 else {
          throw HomebrewError(processResult: result)
        }
        return String(decoding: result.standardOutput, as: UTF8.self)
      }
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
