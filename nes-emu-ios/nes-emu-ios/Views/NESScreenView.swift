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
    var img: CGImage?
    
    var buffer: [UInt32] = PPU.emptyBuffer
    {
        didSet
        {
            let bitmapCount: Int = self.buffer.count
            let elmentLength: Int = 4
            let render: CGColorRenderingIntent = CGColorRenderingIntent.defaultIntent
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
            let providerRef: CGDataProvider? = CGDataProvider(data: NSData(bytes: &self.buffer, length: bitmapCount * elmentLength))
            let cgimage: CGImage? = CGImage(width: 256, height: 224, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 256 * elmentLength, space: rgbColorSpace, bitmapInfo: bitmapInfo, provider: providerRef!, decode: nil, shouldInterpolate: true, intent: render)
            self.img = cgimage
            self.setNeedsDisplay()
        }
    }
    
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
