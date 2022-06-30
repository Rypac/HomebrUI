import Combine
import Foundation

struct HomebrewOperation: Identifiable {
  typealias ID = UUID

  enum Status {
    case queued
    case running
    case completed(ProcessResult)
    case cancelled
  }

  let id: ID
  let command: HomebrewCommand
  let started: Date
  var status: Status
}

actor HomebrewOperationQueue {
  private let configuration: HomebrewConfiguration

  init(configuration: HomebrewConfiguration = .default) {
    self.configuration = configuration
  }

  /// Runs a Homebrew command and returns the result of running the command.
  func run(_ command: HomebrewCommand) async throws -> ProcessResult {
    try await Process.run(
      for: URL(fileURLWithPath: configuration.executablePath),
      arguments: command.arguments
    )
  }
}
