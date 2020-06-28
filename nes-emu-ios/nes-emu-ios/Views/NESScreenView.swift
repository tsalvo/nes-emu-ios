//
//  NESScreenView.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/9/20.
//  Copyright © 2020 Tom Salvo.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import UIKit
import CoreGraphics

class NESScreenView: UIView
{
    var buffer: [UInt32] = PPU.emptyBuffer
    {
        didSet
        {
            let providerRef: CGDataProvider? = CGDataProvider(data: NSData(bytes: &self.buffer, length: NESScreenView.screenWidth * NESScreenView.screenHeight * NESScreenView.elementLength))
            let cgimage: CGImage? = CGImage(width: NESScreenView.screenWidth, height: NESScreenView.screenHeight, bitsPerComponent: NESScreenView.bitsPerComponent, bitsPerPixel: NESScreenView.bitsPerComponent * NESScreenView.elementLength, bytesPerRow: NESScreenView.screenWidth * NESScreenView.elementLength, space: self.rgbColorSpace, bitmapInfo: NESScreenView.bitmapInfo, provider: providerRef!, decode: nil, shouldInterpolate: false, intent: NESScreenView.renderIntent)
            self.img = cgimage
        }
    }
    
    private var img: CGImage?
    {
        didSet
        {
            self.setNeedsDisplay()
        }
    }
    
    private let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    static private let renderIntent: CGColorRenderingIntent = CGColorRenderingIntent.defaultIntent
    static private let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
    static private let elementLength: Int = 4
    static private let screenWidth: Int = 256
    static private let screenHeight: Int = 224
    static private let bitsPerComponent: Int = 8
    
    override func draw(_ rect: CGRect)
    {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext(),
            let img = self.img
        else
        {
            return
        }
        
        context.setAllowsAntialiasing(false)
        context.setShouldAntialias(false)
        context.draw(img, in: self.bounds)
    }
}
