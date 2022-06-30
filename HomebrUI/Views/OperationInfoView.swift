import Combine
import Foundation
import SwiftUI

final class OperationInfoViewModel: ObservableObject {
  struct Operation: Identifiable {
    let id: HomebrewOperation.ID
    let name: String
    let status: String
  }

  @Published private(set) var operations: [Operation] = []

  init(operations: some Publisher<[HomebrewOperation], Never>) {
    operations
      .map { operations in
        operations.map(Operation.init)
      }
      .assign(to: &$operations)
  }
}

struct OperationInfoView: View {
  @StateObject var viewModel: OperationInfoViewModel

  var body: some View {
    VStack {
      Text("Homebrew Operations")
      List(viewModel.operations) { operation in
        HStack {
          Text(operation.name)
          Spacer()
          Text(operation.status)
        }
      }
      .listStyle(.sidebar)
    }
    .padding(.top)
    .frame(minWidth: 350, minHeight: 400)
  }
}

private extension OperationInfoViewModel.Operation {
  init(operation: HomebrewOperation) {
    id = operation.id
    name = operation.command.name
    status = operation.status.name
  }
}

private extension HomebrewCommand {
  var name: String {
    switch self {
    case .list: return "Refreshing packages"
    case .info(let package): return "Getting info for \"\(package)\""
    case .search(let query): return "Searching for \"\(query)\""
    case .install(let packages): return "Installing \(packages)"
    case .uninstall(let package): return "Uninstalling \"\(package)\""
    case .update: return "Updating packages"
    case .upgrade(.all): return "Upgrading all packages"
    case .upgrade(.only(let package)): return "Upgrading \"\(package)\""
    }
  }
}

private extension HomebrewOperation.Status {
  var name: String {
    switch self {
    case .queued: return "Queued"
    case .running: return "Running"
    case .cancelled: return "Cancelled"
    case .completed(let result): return "Completed: Status \(result.status)"
    }
  }
}
