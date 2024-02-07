import SwiftUI
import GameController

public struct ContentView: View {
    
    let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    @State var console: Console = Console(withCartridge: Cartridge(fromData: Data()), sampleRate: ._44100Hz, audioFiltersEnabled: true, state: nil)
    @State var tabSelection = 0
    @State var audioEngine: AudioEngine = AudioEngine()
    @State var didAppear: Bool = false
    @State var showDocumentPicker = true
    @State var showSettings = false
    @State var showBookmarks = false
    
    public var body: some View {
        TabView(selection: $tabSelection) {
            ScreenView(
                screenBuffer: $console.screenBuffer
            )
            .onReceive(timer) { input in
                guard self.didAppear else { return }
                self.console.stepSeconds(seconds: 1.0 / 60.0)
                self.console.set(audioEngineDelegate: self.audioEngine)
                guard let controller = GCController.controllers().first else { return }
                if let pad = controller.extendedGamepad {
                    self.console.set(
                        buttonUpPressed: pad.dpad.up.isPressed || pad.leftThumbstick.up.isPressed,
                        buttonDownPressed: pad.dpad.down.isPressed || pad.leftThumbstick.down.isPressed,
                        buttonLeftPressed: pad.dpad.left.isPressed || pad.leftThumbstick.left.isPressed,
                        buttonRightPressed: pad.dpad.right.isPressed || pad.leftThumbstick.right.isPressed,
                        buttonSelectPressed: (pad.buttonOptions?.isPressed ?? false) || pad.buttonX.isPressed,
                        buttonStartPressed: pad.buttonMenu.isPressed || pad.buttonY.isPressed,
                        buttonBPressed: pad.buttonA.isPressed,
                        buttonAPressed: pad.buttonB.isPressed,
                        forControllerAtIndex: 0
                    )
                }
                else if let pad = controller.microGamepad {
                    self.console.set(
                        buttonUpPressed: pad.dpad.up.isPressed,
                        buttonDownPressed: pad.dpad.down.isPressed,
                        buttonLeftPressed: pad.dpad.left.isPressed,
                        buttonRightPressed: pad.dpad.right.isPressed,
                        buttonSelectPressed: false,
                        buttonStartPressed: pad.buttonMenu.isPressed,
                        buttonBPressed: pad.buttonX.isPressed,
                        buttonAPressed: pad.buttonA.isPressed,
                        forControllerAtIndex: 0
                    )
                }
            }.onAppear {
                self.didAppear = true
            }.sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView(console: $console, tabSelection: $tabSelection)
            }.tabItem {
                Label("Play", systemImage: "play.circle.fill")
            }.tag(0)
            
            
            Spacer()
                .onAppear {
                    showDocumentPicker = true
                    tabSelection = 0
                }.tabItem {
                    Label("Load ROM", systemImage: "folder")
                }.tag(1)
            
            BookmarksView()
                .tabItem {
                    Label("Bookmarks", systemImage: "bookmark")
                }.tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }.tag(3)
            
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}