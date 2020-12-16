import Combine
import Foundation

enum HomebrewCommand {
  case list
  case update
  case upgrade(HomebrewUpgradeStrategy)
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
    case .update:
      return ["update"]
    case .upgrade(.all):
      return ["upgrade"]
    case .upgrade(.only(let package)):
      return ["upgrade", package]
    }
  }
}

private struct HomebrewInput {
  let id: UUID
  let command: HomebrewCommand
}

private struct HomebrewOutput {
  let id: UUID
  let result: Result<ProcessResult, Error>
}

final class HomebrewCommandQueue {
  private let commandQueue = PassthroughSubject<HomebrewInput, Never>()
  private let commandOutput = PassthroughSubject<HomebrewOutput, Never>()

  private var cancellable: AnyCancellable?

  init(configuration: Homebrew.Configuration = .default) {
    cancellable = commandQueue
      .flatMap(maxPublishers: .max(1)) { input in
        Process
          .runPublisher(
            for: URL(fileURLWithPath: configuration.executablePath),
            arguments: input.command.arguments
          )
          .map { output in
            HomebrewOutput(id: input.id, result: .success(output))
          }
          .catch { error in
            Just(HomebrewOutput(id: input.id, result: .failure(error)))
          }
      }
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .finished: print("Finished")
          case .failure: print("Failed")
          }
          self.commandOutput.send(completion: completion)
        },
        receiveValue: { output in
          self.commandOutput.send(output)
        }
      )
  }

  deinit {
    cancellable?.cancel()
    cancellable = nil
  }

  func run(_ command: HomebrewCommand) -> AnyPublisher<ProcessResult, Error> {
    let commandID = UUID()
    commandQueue.send(HomebrewInput(id: commandID, command: command))
    return commandOutput
      .tryCompactMap { output in
        guard output.id == commandID else {
          return nil
        }
        switch output.result {
        case let .success(processResult): return processResult
        case let .failure(error): throw error
        }
      }
      .first()
      .eraseToAnyPublisher()
  }
}
