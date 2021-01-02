//
//  UInt8+ByteUtils.swift
//  nes-ide-ios
//
//  Created by Tom Salvo on 7/23/18.
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

extension UInt8
{
    /// returns a string of 0s and 1s representing the UInt8 value.  bits are in big endian order (most significant bits first)
    var binaryString: String
    {
        var result: String = ""
        for i in (0 ... 7).reversed()
        {
            result.append(self >> i & 1 == 1 ? "1" : "0")
        }
        return result
    }
    
    /// Returns a UInt8 value from an array of 8 boolean values in big endian order (more significant, or "higher", bits first)
    init(fromBigEndianBitArray aBigEndianBitArray: [Bool])
    {
        var retValue: UInt8 = 0
        if aBigEndianBitArray.count == 8
        {
            retValue += aBigEndianBitArray[7] ? 1 : 0
            retValue += aBigEndianBitArray[6] ? 2 : 0
            retValue += aBigEndianBitArray[5] ? 4 : 0
            retValue += aBigEndianBitArray[4] ? 8 : 0
            retValue += aBigEndianBitArray[3] ? 16 : 0
            retValue += aBigEndianBitArray[2] ? 32 : 0
            retValue += aBigEndianBitArray[1] ? 64 : 0
            retValue += aBigEndianBitArray[0] ? 128 : 0
        }
        
        self.init(retValue)
    }
    
    /// Returns an array of 8 boolean values in little-endian order (less significant, or "lower", bits first)
    var littleEndianBitArray: [Bool]
    {
        let lE = self.littleEndian
        var retValue: [Bool] = [Bool].init(repeating: false, count: 8)
        
        retValue[0] = lE >> 0 & 1 == 1
        retValue[1] = lE >> 1 & 1 == 1
        retValue[2] = lE >> 2 & 1 == 1
        retValue[3] = lE >> 3 & 1 == 1
        retValue[4] = lE >> 4 & 1 == 1
        retValue[5] = lE >> 5 & 1 == 1
        retValue[6] = lE >> 6 & 1 == 1
        retValue[7] = lE >> 7 & 1 == 1
        
        return retValue
    }
    
    /// Returns a UInt8 value from an array of 8 boolean values in little endian order (less significant, or "lower", bits first)
    init(fromLittleEndianBitArray aLittleEndianBitArray: [Bool])
    {
        var retValue: UInt8 = 0
        if aLittleEndianBitArray.count == 8
        {
            retValue += aLittleEndianBitArray[0] ? 1 : 0
            retValue += aLittleEndianBitArray[1] ? 2 : 0
            retValue += aLittleEndianBitArray[2] ? 4 : 0
            retValue += aLittleEndianBitArray[3] ? 8 : 0
            retValue += aLittleEndianBitArray[4] ? 16 : 0
            retValue += aLittleEndianBitArray[5] ? 32 : 0
            retValue += aLittleEndianBitArray[6] ? 64 : 0
            retValue += aLittleEndianBitArray[7] ? 128 : 0
        }
        
        self.init(retValue)
    }
}
