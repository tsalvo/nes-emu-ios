import SwiftUI

struct SettingsView: View {
    @Binding var showSettings: Bool
    var body: some View {
        VStack {
            Button.init("", systemImage: "xmark") {
                showSettings = false
            }
            Text("Settings")
        }
    }
}
