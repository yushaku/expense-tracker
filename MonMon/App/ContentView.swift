import SwiftUI

struct ContentView: View {
    var body: some View {
        RootTabView()
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
}

#if DEBUG
    #Preview("App · accounts") {
        ContentView()
            .modelContainer(PreviewData.populated)
    }

    #Preview("App · empty") {
        ContentView()
            .modelContainer(PreviewData.empty)
    }
#endif
