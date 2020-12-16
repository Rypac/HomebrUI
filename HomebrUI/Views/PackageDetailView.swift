import SwiftUI

struct PackageDetailView: View {
  let package: Package

  var body: some View {
    VStack {
      HStack {
        Text(package.name)
          .font(.title)
        Spacer()
        Text(package.version)
          .font(.headline)
          .foregroundColor(.secondary)
      }
      Spacer()
    }
    .padding()
  }
}
