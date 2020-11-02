//
//  Scanlines.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/31/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

enum Scanlines: UInt8, CaseIterable, SettingsEnum
{
    case off = 0,
    low = 119,
    med = 170,
    hi = 255
    
    var friendlyName: String
    {
        switch self
        {
        case .off: return "off"
        case .low: return "low"
        case .med: return "med"
        case .hi: return "hi"
        }
    }
    
    var storedValue: Any { return self.rawValue }
    
    func colorArray() -> [UInt32]
    {
        let scanlineColor: UInt32 = UInt32(self.rawValue)
        
        var array: [UInt32] = [UInt32].init(repeating: 0, count: PPU.screenHeight * 2)
        
        for i in (0 ..< PPU.screenHeight * 2).filter({ $0 % 2 == 1 })
        {
            array[i] = scanlineColor
        }
        
        return array
    }
}
