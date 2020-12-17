import SwiftUI

struct AppCommands: Commands {
  let repository: PackageRepository

  var body: some Commands {
    SidebarCommands()
    ViewCommands()
    PackageCommands(repository: repository)
  }
}
