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
    var buffer: [UInt32] = [UInt32].init(repeating: 0, count: 240 * 256)
    {
        didSet
        {
            self.setNeedsDisplay()
        }
    }
    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect)
    {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext()
        else
        {
            return
        }

        self.buffer.withUnsafeMutableBytes { pointer in
            let bitmapContext = CGContext(data: pointer.baseAddress, width: 256, height: 240, bitsPerComponent: 8, bytesPerRow: 256 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue).rawValue)
            bitmapContext?.setAllowsAntialiasing(false)
            bitmapContext?.setShouldAntialias(false)
            guard let img = bitmapContext?.makeImage() else { return }
            context.setAllowsAntialiasing(false)
            context.setShouldAntialias(false)
            context.draw(img, in: self.bounds)
        }
    }
}
