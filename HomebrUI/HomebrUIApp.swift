import SwiftUI

@main
struct HomebrUIApp: App {
  private let packageRepository: PackageRepository
  private let operationRepository: OperationRepository

  init() {
    let homebrew = Homebrew()
    packageRepository = PackageRepository(homebrew: homebrew)
    operationRepository = OperationRepository(homebrew: homebrew)
  }

  var body: some Scene {
    WindowGroup  {
      ContentView(packageRepository: packageRepository, operationRepository: operationRepository)
        .frame(minHeight: 400, idealHeight: 700)
    }
    .commands {
      AppCommands(repository: packageRepository)
    }
  }
}
