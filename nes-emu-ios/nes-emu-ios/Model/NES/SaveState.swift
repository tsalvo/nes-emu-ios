//
//  SaveState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 7/15/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

struct ConsoleState
{
    let cpuState: CPUState
    let apuState: APUState
    let ppuState: PPUState
    let mapperState: MapperState
}

struct CPUState
{
    let ram: [UInt8]
    let a: UInt8
    let x: UInt8
    let y: UInt8
    let pc: UInt16
    let cycles: UInt64
    let flags: UInt8
    let interrupt: UInt8
    let stall: Int
}

struct APUState
{
    
}

struct PPUState
{
    let cycle: Int
    let frame: UInt64
    let paletteData: [UInt8]
    let nameTableData: [UInt8]
    let oamData: [UInt8]
    
    // MARK: PPU Registers
    
    /// current vram address (15 bit)
    let v: UInt16
    
    /// temporary vram address (15 bit)
    let t: UInt16
    
    /// fine x scroll (3 bit)
    let x: UInt8
    
    /// write toggle bit
    let w: Bool
    
    /// even / odd frame flag bit
    let f: Bool
    
    let register: UInt8
    
    // MARK: NMI flags
    let nmiOccurred: Bool
    let nmiOutput: Bool
    let nmiPrevious: Bool
    let nmiDelay: UInt8
    
    // MARK: Background temporary variables
    let nameTableByte: UInt8
    let attributeTableByte: UInt8
    let lowTileByte: UInt8
    let highTileByte: UInt8
    let tileData: UInt64
    
    // MARK: Sprite temporary variables
    let spriteCount: Int
    let spritePatterns: [UInt32]
    let spritePositions: [UInt8]
    let spritePriorities: [UInt8]
    let spriteIndexes: [UInt8]
    
    // MARK: $2000 PPUCTRL
    /// 0: $2000; 1: $2400; 2: $2800; 3: $2C00
    let flagNameTable: UInt8
    
    /// 0: add 1; 1: add 32
    let flagIncrement: Bool
    
    /// 0: $0000; 1: $1000; ignored in 8x16 mode
    let flagSpriteTable: Bool
    
    /// 0: $0000; 1: $1000
    let flagBackgroundTable: Bool
    
    /// 0: 8x8; 1: 8x16
    let flagSpriteSize: Bool
    
    /// 0: read EXT; 1: write EXT
    let flagMasterSlave: Bool
    
    // MARK: $2001 PPUMASK
    /// false: color; true: grayscale
    let flagGrayscale: Bool
    
    /// false: hide; true: show
    let flagShowLeftBackground: Bool
    
    /// false: hide; true: show
    let flagShowLeftSprites: Bool
    
    /// false: hide; true: show
    let flagShowBackground: Bool
    
    /// false: hide; true: show
    let flagShowSprites: Bool
    
    /// false: normal; true: emphasized
    let flagRedTint: Bool
    
    /// false: normal; true: emphasized
    let flagGreenTint: Bool
    
    /// false: normal; true: emphasized
    let flagBlueTint: Bool
    
    // MARK: $2002 PPUSTATUS
    let flagSpriteZeroHit: UInt8
    let flagSpriteOverflow: UInt8
    
    // $2003 OAMADDR
    let oamAddress: UInt8
    
    // $2007 PPUDATA
    /// for buffered reads
    let bufferedData: UInt8
    
    // MARK: Pixel Buffer
    
    /// colors in 0xBBGGRRAA format from Palette.colors
    let frontBuffer: [UInt32]
    
    let scanline: Int
}

struct MapperState
{
    let mirroringMode: UInt8
    let ints: [Int]
    let bools: [Bool]
    let uint8s: [UInt8]
}
