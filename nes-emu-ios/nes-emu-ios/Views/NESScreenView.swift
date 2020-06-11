//
//  NESScreenView.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/9/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

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
            let cgimage: CGImage? = CGImage(width: 256, height: 240, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 256 * elmentLength, space: rgbColorSpace, bitmapInfo: bitmapInfo, provider: providerRef!, decode: nil, shouldInterpolate: true, intent: render)
            if cgimage != nil
            {
                self.img = cgimage
                self.setNeedsDisplay()
            }
        }
    }
    
    override func draw(_ rect: CGRect)
    {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext(),
            let img = self.img else { return
        }
        
        context.draw(img, in: self.bounds)
    }
}
