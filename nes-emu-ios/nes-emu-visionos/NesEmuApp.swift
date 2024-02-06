import SwiftUI

@main
struct NesEmuApp: App {
    static private let defaultSizeMultiplier: Int = 4
    var body: some Scene {
        WindowGroup {
            ContentView()
        }.defaultSize(
            CGSize(
                width: PPU.screenWidth * Self.defaultSizeMultiplier,
                height: PPU.screenHeight * Self.defaultSizeMultiplier
            )
        )
    }
}
