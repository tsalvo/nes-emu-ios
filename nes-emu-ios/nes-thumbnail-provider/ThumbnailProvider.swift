//
//  ThumbnailProvider.swift
//  nes-thumbnail-provider
//
//  Created by Tom Salvo on 6/13/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit
import QuickLookThumbnailing
import os

class ThumbnailProvider: QLThumbnailProvider
{
    private class ThumbnailView: UIView
    {
        static private let bgColorCG: CGColor = UIColor.init(white: 0.7, alpha: 1.0).cgColor
        static private let cartridgeColorCG: CGColor = UIColor.init(white: 0.3, alpha: 1.0).cgColor
        static private let cartridgeGripColorCG: CGColor = UIColor.init(white: 0.23, alpha: 1.0).cgColor
        static private let cartridgeLabelColorCG: CGColor = UIColor.init(white: 0.8, alpha: 1.0).cgColor
        static private let supportedLabelColorCG: CGColor = UIColor.init(red: 0.15, green: 0.5, blue: 0.15, alpha: 1.0).cgColor
        static private let unsupportedLabelColorCG: CGColor = UIColor.init(red: 0.5, green: 0.15, blue: 0.15, alpha: 1.0).cgColor
        
        let romHeader: RomHeader
        
        init(frame aFrame: CGRect, romHeader aRomheader: RomHeader)
        {
            self.romHeader = aRomheader
            super.init(frame: aFrame)
            self.backgroundColor = UIColor.white
        }
        
        required init?(coder aDecoder: NSCoder) {
            os_log(OSLogType.error, "Thumbnail Provider - init(coder:) has not been implemented")
            fatalError("init(coder:) has not been implemented")
        }
        
        override func draw(_ rect: CGRect)
        {
            super.draw(rect)
            
            guard let context = UIGraphicsGetCurrentContext() else { return }
            
            context.setFillColor(UIColor.init(white: 0.7, alpha: 1.0).cgColor)
            context.fill(rect)
            
            let ridges: Int = 9
            let cartridgeLabelInnerColor: CGColor = (self.romHeader.mapperIdentifier?.isSupported ?? false) ? ThumbnailView.supportedLabelColorCG : ThumbnailView.unsupportedLabelColorCG
            
            let cartridgeTop: CGFloat = rect.height * 0.05
            let cartridgeLeading: CGFloat = rect.width * 0.05
            let cartridgeLeadingInner: CGFloat = rect.width * 0.1
            let cartridgeWidth: CGFloat = rect.width - (2.0 * cartridgeLeading)
            let cartridgeWidthInner: CGFloat = rect.width - (2.0 * cartridgeLeadingInner)
            let cartridgeHeightOuter: CGFloat = (rect.height - (2.0 * cartridgeTop)) * 0.85
            let cartridgeHeightInner: CGFloat = (rect.height - (2.0 * cartridgeTop)) * 0.15
            let cartridgeTopInner: CGFloat = cartridgeTop + cartridgeHeightOuter
            let cartridgeGripLeading: CGFloat = cartridgeLeading + (cartridgeWidth * 0.115)
            let cartridgeGripWidth: CGFloat = cartridgeWidth * 0.2
            let cartridgeGripHeight: CGFloat = (cartridgeHeightOuter + cartridgeHeightInner) * 0.95
            let cartridgeLabelLeading: CGFloat = cartridgeLeading + (cartridgeWidth * 0.4)
            let cartridgeLabelWidth: CGFloat = cartridgeWidth * 0.48
            let cartridgeLabelHeight: CGFloat = cartridgeHeightOuter * 0.8
            let cartridgeLabelInnerTop: CGFloat = cartridgeTop + cartridgeLabelHeight * 0.1
            let cartridgeLabelInnerLeading: CGFloat = cartridgeLabelLeading + cartridgeLabelWidth * 0.1
            let cartridgeLabelInnerWidth: CGFloat = cartridgeLabelWidth * 0.8
            let cartridgeLabelInnerHeight: CGFloat = cartridgeLabelHeight * 0.8
            
            let cartridgeRect1: CGRect = CGRect(x: cartridgeLeading, y: cartridgeTop, width: cartridgeWidth, height: cartridgeHeightOuter)
            let cartridgeRect2: CGRect = CGRect(x: cartridgeLeadingInner, y: cartridgeTopInner, width: cartridgeWidthInner, height: cartridgeHeightInner)
            let cartridgeLabelRect: CGRect = CGRect(x: cartridgeLabelLeading, y: cartridgeTop, width: cartridgeLabelWidth, height: cartridgeLabelHeight)
            let cartridgeLabelInnerRect: CGRect = CGRect(x: cartridgeLabelInnerLeading, y: cartridgeLabelInnerTop, width: cartridgeLabelInnerWidth, height: cartridgeLabelInnerHeight)
            
            context.setFillColor(ThumbnailView.cartridgeColorCG)
            context.fill(cartridgeRect1)
            context.fill(cartridgeRect2)
            context.setFillColor(ThumbnailView.cartridgeGripColorCG)
            for i in 0 ..< ridges
            {
                let y = cartridgeTop + (CGFloat(i) * cartridgeGripHeight / CGFloat(ridges))
                let height = (cartridgeGripHeight / CGFloat(ridges)) * 0.6
                context.fill(CGRect(x: cartridgeGripLeading, y: y, width: cartridgeGripWidth, height: height))
            }
            
            context.setFillColor(ThumbnailView.cartridgeLabelColorCG)
            context.fill(cartridgeLabelRect)
            context.setFillColor(cartridgeLabelInnerColor)
            context.fill(cartridgeLabelInnerRect)
        }
    }
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        // Draw the thumbnail into the current context, set up with UIKit's coordinate system.
        handler(QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: { () -> Bool in
            
            let romData: Data
            
            do
            {
                romData = try Data.init(contentsOf: request.fileURL)
            }
            catch
            {
                return false
            }
            
            let tView = ThumbnailView(frame: CGRect(origin: .zero, size: request.maximumSize), romHeader: RomHeader.init(fromData: romData.prefix(16)))
            
            tView.draw(tView.bounds)
            
            return true
        }), nil)
    }
}
