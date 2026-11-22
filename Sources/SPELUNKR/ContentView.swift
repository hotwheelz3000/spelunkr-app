import SwiftUI

struct ContentView: View {
    private let homeURL = URL(string: "https://spelunkr.tv/")!

    var body: some View {
        ZStack {
            // Fills the status bar and home indicator areas with the site's purple.
            Color(uiColor: .spelunkrPurple)
                .ignoresSafeArea()
            // The page itself stays inside the safe area, so the notch and the
            // home indicator never cover the player or its controls.
            WebView(url: homeURL)
        }
    }
}
