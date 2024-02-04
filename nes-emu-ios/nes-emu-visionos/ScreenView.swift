import SwiftUI

struct ScreenView: View {
    @Binding var screenBuffer: [UInt32]
    static private let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    static private let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
    static private let elementLength: Int = 4
    static private let bitsPerComponent: Int = 8
    
    var body: some View {
        Image(decorative: CGImage(
            width: PPU.screenWidth,
            height: PPU.screenHeight,
            bitsPerComponent: Self.bitsPerComponent,
            bitsPerPixel: Self.bitsPerComponent * Self.elementLength,
            bytesPerRow: PPU.screenWidth * ScreenView.elementLength,
            space: Self.rgbColorSpace,
            bitmapInfo: Self.bitmapInfo,
            provider: CGDataProvider(data: CFDataCreate(kCFAllocatorDefault, [UInt8](Data(fromArray: self.screenBuffer)), PPU.screenWidth * PPU.screenHeight * Self.elementLength))!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent)!, scale: 1.0
        ).resizable().aspectRatio(/*CGFloat(PPU.screenWidth) / CGFloat(PPU.screenHeight), */contentMode: .fit)
    }
}
