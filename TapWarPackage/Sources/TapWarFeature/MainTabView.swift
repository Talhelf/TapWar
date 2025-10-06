import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Tab = .tap

    enum Tab {
        case tap
        case leaderboard
    }

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            TapView()
                .tag(Tab.tap)
                .tabItem {
                    Label("Battle", systemImage: "hand.tap.fill")
                }

            LeaderboardView()
                .tag(Tab.leaderboard)
                .tabItem {
                    Label("Rankings", systemImage: "trophy.fill")
                }
        }
        .accentColor(.yellow)
    }
}
