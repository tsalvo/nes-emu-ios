//
//  PPU.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/5/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

enum MirroringMode
{
    case horizontal, vertical, single0, single1, fourScreen
    
    var nameTableOffsetSequence: [UInt16]
    {
        switch self
        {
        case .horizontal: return [0, 0, 1024, 1024]
        case .vertical: return [0, 1024, 0, 1024]
        case .single0: return [0, 0, 0, 0]
        case .single1: return [1024, 1024, 1024, 1024]
        case .fourScreen: return [0, 1024, 2048, 3072]
        }
    }
}

/// NES Picture Processing Unit
class PPU
{
    weak var console: ConsoleProtocol?
    private let memory: Memory = PPUMemory()
    
    func readRegister(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x2002:
            return self.readStatus()
        case 0x2004:
            return self.readOAMData()
        case 0x2007:
            return self.readData()
        default: return 0
        }
    }
    
    /// $2002: PPUSTATUS
    func readStatus() -> UInt8
    {
        return 0
    }
    
    /// $2004: OAMDATA (read)
    func readOAMData() -> UInt8
    {
        return 0
    }
    
    /// $2007: PPUDATA (read)
    func readData() -> UInt8
    {
        return 0
    }
}
