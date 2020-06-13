//
//  SampleRate.swift
//  October
//
//  Created by Tom Salvo on 2/17/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

enum SampleRate: Int, CaseIterable
{
    case _22050Hz = 22050,
    _44100Hz = 44100
    
    var floatValue: Float { return Float(self.rawValue) }
    var doubleValue: Double { return Double(self.rawValue) }
    var ticksPerNodeTapBuffer: Int { return 6 }
    var nodeTapBufferCapacity: UInt32 { return UInt32(self.rawValue) / 10 }
    
    /// number of samples for a buffer of one tick length (1/60 second)
    var bufferCapacity: UInt32 { return UInt32(self.rawValue) / 60 }
    
    var friendlyName: String
    {
        return "\(self.rawValue)Hz"
    }
    
    var storedValue: Any { return self.rawValue }
}
