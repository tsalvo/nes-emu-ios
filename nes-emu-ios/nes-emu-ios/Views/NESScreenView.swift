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
    private let queue: DispatchQueue = DispatchQueue.init(label: "renderQueue", qos: .userInteractive)
    private var hasSuspended: Bool = false
    private let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    private let context: CIContext
    private let commandQueue: MTLCommandQueue
    private var nearestNeighborRendering: Bool
    private var integerScaling: Bool
    private var checkForRedundantFrames: Bool
    private var scanlines: Scanlines
    private var currentScale: CGFloat = 1.0
    private var viewportOffset: CGPoint = CGPoint.zero
    private var lastDrawableSize: CGSize = CGSize.zero
    private var scanlineBuffer: [UInt32]
    private var scanlineBaseImage: CIImage
    private var scanlineImage: CIImage = CIImage.empty()
    private var tNesScreen: CGAffineTransform = CGAffineTransform.identity
    static private let elementLength: Int = 4
    static private let bitsPerComponent: Int = 8
    static private let imageSize: CGSize = CGSize(width: PPU.screenWidth, height: PPU.screenHeight)

    required init(coder: NSCoder)
    {
        let dev: MTLDevice = MTLCreateSystemDefaultDevice()!
        let commandQueue = dev.makeCommandQueue()!
        let s: Scanlines = Scanlines(rawValue: UInt8(UserDefaults.standard.integer(forKey: Settings.scanlinesKey))) ?? Settings.defaultScanlinesKey
        self.context = CIContext.init(mtlCommandQueue: commandQueue, options: [.cacheIntermediates: false])
        self.commandQueue = commandQueue
        self.nearestNeighborRendering = UserDefaults.standard.bool(forKey: Settings.nearestNeighborRenderingKey)
        self.checkForRedundantFrames = UserDefaults.standard.bool(forKey: Settings.checkForRedundantFramesKey)
        self.integerScaling = UserDefaults.standard.bool(forKey: Settings.integerScalingKey)
        self.scanlines = s
        self.scanlineBuffer = s.colorArray()
        self.scanlineBaseImage = CIImage(bitmapData: NSData(bytes: &self.scanlineBuffer, length: PPU.screenHeight * 2 *  NESScreenView.elementLength) as Data, bytesPerRow: NESScreenView.elementLength, size: CGSize(width: 1, height: PPU.screenHeight * 2), format: CIFormat.ARGB8, colorSpace: self.rgbColorSpace)
        super.init(coder: coder)
        self.device = dev
        self.autoResizeDrawable = true
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
            guard !self.checkForRedundantFrames || self.drawableSize != self.lastDrawableSize || !self.buffer.elementsEqual(oldValue)
                else
            {
                return
            }
            
            self.queue.async { [weak self] in
                self?.draw()
            }
        }
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    {
        let exactScale: CGFloat = size.width / CGFloat(PPU.screenWidth)
        self.currentScale = self.integerScaling ? floor(exactScale) : exactScale
        self.viewportOffset = self.integerScaling ? CGPoint(x: (size.width - (CGFloat(PPU.screenWidth) * self.currentScale)) * 0.5, y: (size.height - (CGFloat(PPU.screenHeight) * self.currentScale)) * 0.5) : CGPoint.zero
        
        let t1: CGAffineTransform = CGAffineTransform(scaleX: self.currentScale, y: self.currentScale)
        let t2: CGAffineTransform = self.integerScaling ? CGAffineTransform(translationX: self.viewportOffset.x, y: self.viewportOffset.y) : CGAffineTransform.identity
        self.tNesScreen = t1.concatenating(t2)
        
        switch self.scanlines
        {
        case .off: break
        default:
            let t1s: CGAffineTransform = CGAffineTransform(scaleX: self.currentScale * CGFloat(PPU.screenWidth), y: self.currentScale * 0.5)
            let t: CGAffineTransform = t1s.concatenating(t2)
            self.scanlineImage = self.scanlineBaseImage.samplingNearest().transformed(by: t)
        }
    }

    func draw(in view: MTKView)
    {
        guard let safeCurrentDrawable = self.currentDrawable,
            let safeCommandBuffer = self.commandQueue.makeCommandBuffer()
        else
        {
            return
        }
        
        let image: CIImage
        let baseImage: CIImage = CIImage(bitmapData: NSData(bytes: &self.buffer, length: PPU.screenWidth * PPU.screenHeight * NESScreenView.elementLength) as Data, bytesPerRow: PPU.screenWidth * NESScreenView.elementLength, size: NESScreenView.imageSize, format: CIFormat.ARGB8, colorSpace: self.rgbColorSpace)
        
        if self.nearestNeighborRendering
        {
            image = self.scanlineImage.composited(over: baseImage.samplingNearest().transformed(by: self.tNesScreen))
        }
        else
        {
            image = self.scanlineImage.composited(over: baseImage.transformed(by: self.tNesScreen))
        }
        
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
        
        self.lastDrawableSize = self.drawableSize
    }
    
    @objc private func appResignedActive()
    {
        self.queue.suspend()
        self.hasSuspended = true
    }
    
    @objc private func appBecameActive()
    {
        if self.hasSuspended
        {
            self.queue.resume()
            self.hasSuspended = false
        }
    }
}
