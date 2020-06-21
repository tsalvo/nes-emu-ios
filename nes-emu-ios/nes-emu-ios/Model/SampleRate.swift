//
//  SampleRate.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 2/17/20.
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

enum SampleRate: Int, CaseIterable, SettingsEnum
{
    case _12000Hz = 12000,
    _16000Hz = 16000,
    _22050Hz = 22050,
    _44100Hz = 44100
    
    var floatValue: Float { return Float(self.rawValue) }
    var doubleValue: Double { return Double(self.rawValue) }
    var ticksPerNodeTapBuffer: Int { return 6 }
    var nodeTapBufferCapacity: UInt32 { return UInt32(self.rawValue) / 10 }
    
    /// number of samples for a buffer of one tick length (1/60 second)
    var bufferCapacity: UInt32 { return UInt32(self.rawValue) / 60 }
    
    var friendlyName: String
    {
        switch self
        {
        case ._12000Hz: return "12"
        case ._16000Hz: return "16"
        case ._22050Hz: return "22"
        case ._44100Hz: return "44"
        }
    }
    
    var storedValue: Any { return self.rawValue }
}
