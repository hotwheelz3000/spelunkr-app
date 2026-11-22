import SwiftUI
import UIKit

struct ContentView: View {
    @State private var state = PageState(homeURL: URL(string: "https://spelunkr.tv/")!)

    var body: some View {
        ZStack {
            // Fills the status bar and home indicator areas with the site's purple.
            Color(uiColor: .spelunkrPurple)
                .ignoresSafeArea()
            // The page itself stays inside the safe area, so the notch and the
            // home indicator never cover the player or its controls.
            WebView(state: state)

            if state.offline {
                OfflineView { state.retry() }
                    .transition(.opacity)
            } else if !state.loaded {
                LoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: state.loaded)
        .animation(.easeOut(duration: 0.25), value: state.offline)
    }
}

/// The icon on purple with a spinner, until the first channel loads.
private struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .spelunkrPurple).ignoresSafeArea()
            VStack(spacing: 28) {
                AppIconImage()
                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
            }
        }
    }
}

private struct OfflineView: View {
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color(uiColor: .spelunkrPurple).ignoresSafeArea()
            VStack(spacing: 18) {
                AppIconImage()
                    .opacity(0.6)
                Text("No connection")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("SPELUNKR needs the internet to tune in.\nIt'll try again when you're back online.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                Button(action: retry) {
                    Text("Retry")
                        .font(.headline)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .background(Color.white, in: Capsule())
                        .foregroundStyle(Color(uiColor: .spelunkrPurple))
                }
                .padding(.top, 6)
            }
            .padding(32)
        }
    }
}

private struct AppIconImage: View {
    private static let image: UIImage? = Bundle.module
        .path(forResource: "LaunchIcon", ofType: "png")
        .flatMap { UIImage(contentsOfFile: $0) }

    var body: some View {
        if let image = Self.image {
            Image(uiImage: image)
                .resizable()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        }
    }
}
