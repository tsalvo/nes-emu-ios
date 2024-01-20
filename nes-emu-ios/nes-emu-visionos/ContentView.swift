import SwiftUI
import GameController

struct ControllerInput: Equatable {
    var up: Bool = false
    var down: Bool = false
    var left: Bool = false
    var right: Bool = false
    var select: Bool = false
    var start: Bool = false
    var b: Bool = false
    var a: Bool = false
}

public struct ContentView: View {
    let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    @State var console: Console
    @State var audioEngine: AudioEngine = AudioEngine()
    @State var input: ControllerInput = ControllerInput()
    
    public init(document: NesDocument) {
        self._console = .init(
            initialValue:
                Console(
                    withCartridge: Cartridge(fromData: document.romData),
                    sampleRate: ._22050Hz,
                    audioFiltersEnabled: false,
                    state: nil
                )
            )
        self._input = .init(initialValue: ControllerInput())
    }
    
    public var body: some View {
        ZStack {
            VStack {
                ScreenView(
                    input: $input,
                    screenBuffer: $console.screenBuffer)
                Spacer()
            }
            ControllerView(input: $input)
        }.onReceive(timer) { input in
            self.console.stepSeconds(seconds: 1.0 / 60.0)
        }.onChange(of: input) { _, newValue in
            self.console.set(buttonUpPressed: newValue.up, buttonDownPressed: newValue.down, buttonLeftPressed: newValue.left, buttonRightPressed: newValue.right, buttonSelectPressed: newValue.select, buttonStartPressed: newValue.start, buttonBPressed: newValue.b, buttonAPressed: newValue.a, forControllerAtIndex: 0)
        }.onAppear {
            self.console.set(audioEngineDelegate: self.audioEngine)
            self.console.reset()
        }.navigationBarTitleDisplayMode(.inline)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: NesDocument())
    }
}
