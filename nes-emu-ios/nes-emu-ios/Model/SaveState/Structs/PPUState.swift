//
//  PPUState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/10/20.
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

import Foundation

struct PPUState
{
    let cycle: UInt16
    let scanline: UInt16
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
    let nmiPrevious: Bool // TODO: remove (unused)
    let nmiDelay: UInt8
    
    // MARK: Background temporary variables
    let nameTableByte: UInt8
    let attributeTableByte: UInt8
    let lowTileByte: UInt8
    let highTileByte: UInt8
    let tileData: UInt64
    
    // MARK: Sprite temporary variables
    let spriteCount: UInt8
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
}
