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
    .frame(minWidth: 300)
  }
}

struct PackageDetailPlaceholderView: View {
  var body: some View {
    Text("Select a Package")
      .font(.callout)
      .foregroundColor(.secondary)
  }
}
