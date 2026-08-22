import SwiftUI

struct ContentView: View {
    var body: some View {
        Text(AppCopy.greeting)
            .font(.title.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("app-greeting")
    }
}
