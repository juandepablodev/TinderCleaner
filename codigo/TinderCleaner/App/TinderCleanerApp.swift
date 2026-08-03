import SwiftUI

@main
struct TinderCleanerApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

struct ContentView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "photo.on.rectangle.angled")
        .font(.system(size: 60))
        .foregroundStyle(.tint)

      Text("TinderCleaner")
        .font(.largeTitle.bold())

      Text("Clean your photo library efficiently and privately.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
