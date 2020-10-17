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
import MetalKit
import os

class NESScreenView: MTKView, MTKViewDelegate
{
    private var queue: DispatchQueue = DispatchQueue.init(label: "renderQueue", qos: .userInteractive)

    private let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    private let context: CIContext
    private let commandQueue: MTLCommandQueue
    static private let elementLength: Int = 4
    static private let bitsPerComponent: Int = 8
    static private let imageSize: CGSize = CGSize(width: PPU.screenWidth, height: PPU.screenHeight)

    required init(coder: NSCoder)
    {
        let dev: MTLDevice = MTLCreateSystemDefaultDevice()!
        let commandQueue = dev.makeCommandQueue()!
        self.context = CIContext.init(mtlCommandQueue: commandQueue, options: [.cacheIntermediates: false])
        self.commandQueue = commandQueue

        super.init(coder: coder)
        
        self.device = dev
        self.autoResizeDrawable = false
        self.drawableSize = CGSize(width: PPU.screenWidth, height: PPU.screenHeight)
        self.isPaused = true
        self.enableSetNeedsDisplay = false
        self.framebufferOnly = false
        self.delegate = self
        self.isOpaque = true
        self.clearsContextBeforeDrawing = false
        NotificationCenter.default.addObserver(self, selector: #selector(appResignedActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }

    var buffer: [UInt32] = PPU.emptyBuffer
    {
        didSet
        {
            self.queue.async { [weak self] in
                self?.draw()
            }
        }
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    {

    }

    func draw(in view: MTKView)
    {
        guard let safeCurrentDrawable = self.currentDrawable,
            let safeCommandBuffer = self.commandQueue.makeCommandBuffer()
        else
        {
            return
        }
        
        let image = CIImage(bitmapData: NSData(bytes: &self.buffer, length: PPU.screenWidth * PPU.screenHeight * NESScreenView.elementLength) as Data, bytesPerRow: PPU.screenWidth * NESScreenView.elementLength, size: NESScreenView.imageSize, format: CIFormat.ARGB8, colorSpace: self.rgbColorSpace)
        let renderDestination = CIRenderDestination(width: Int(self.drawableSize.width), height: Int(self.drawableSize.height), pixelFormat: self.colorPixelFormat, commandBuffer: safeCommandBuffer) {
            () -> MTLTexture in return safeCurrentDrawable.texture
        }
        
        do
        {
            let _ = try self.context.startTask(toRender: image, to: renderDestination)
        }
        catch
        {
            os_log("%@", error.localizedDescription)
        }
        
        safeCommandBuffer.present(safeCurrentDrawable)
        safeCommandBuffer.commit()
    }
    
    @objc private func appResignedActive()
    {
        self.queue.suspend()
    }
    
    @objc private func appBecameActive()
    {
        self.queue.resume()
    }
}
