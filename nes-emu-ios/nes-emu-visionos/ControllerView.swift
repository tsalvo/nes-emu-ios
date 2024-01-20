import SwiftUI

struct ControllerView: View {
    static private let buttonSize: CGFloat = 44.0
    @Binding var input: ControllerInput
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                HStack {
                    Spacer().frame(width: geometry.size.width * 0.05)
                    VStack {
                        Spacer().frame(height: Self.buttonSize)
                        Button {} label: {
                            Image(systemName: "arrow.left")
                        }.onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { _ in
                            input.left.toggle()
                        }).frame(width: Self.buttonSize, height: Self.buttonSize)
                        Spacer().frame(height: Self.buttonSize)
                    }
                    VStack {
                        Button {} label: {
                            Image(systemName: "arrow.up")
                        }.onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { _ in
                            input.up.toggle()
                        }).frame(width: Self.buttonSize, height: Self.buttonSize)
                        Spacer().frame(height: Self.buttonSize)
                        Button {} label: {
                            Image(systemName: "arrow.down")
                        }.onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { _ in
                            input.down.toggle()
                        }).frame(width: Self.buttonSize, height: Self.buttonSize)
                    }
                    VStack {
                        Spacer().frame(height: Self.buttonSize)
                        Button {} label: {
                            Image(systemName: "arrow.right")
                        }.onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { _ in
                            input.right.toggle()
                        }).frame(width: Self.buttonSize, height: Self.buttonSize)
                        Spacer().frame(height: Self.buttonSize)
                    }
                    Spacer()
                    VStack {
                        Button {} label: {
                            Image(systemName: "capsule")
                        }.onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { _ in
                            input.select.toggle()
                        }).frame(width: Self.buttonSize, height: Self.buttonSize)
                        Spacer().frame(height: Self.buttonSize)
                        Button {} label: {
                            Image(systemName: "b.circle")
                        }.onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { _ in
                            input.b.toggle()
                        }).frame(width: Self.buttonSize, height: Self.buttonSize)
                    }
                    Spacer().frame(width: Self.buttonSize)
                    VStack {
                        Button {} label: {
                            Image(systemName: "capsule")
                        }.onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { _ in
                            input.start.toggle()
                        }).frame(width: Self.buttonSize, height: Self.buttonSize)
                        Spacer().frame(height: Self.buttonSize)
                        Button {} label: {
                            Image(systemName: "a.circle")
                        }.onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { _ in
                            input.a.toggle()
                        }).frame(width: Self.buttonSize, height: Self.buttonSize)
                    }
                    Spacer().frame(width: geometry.size.width * 0.05)
                }
            }
        }
    }
}
