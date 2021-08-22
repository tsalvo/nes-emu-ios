//
//  NSManagedObject+APUState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
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
import CoreData

extension NSManagedObject
{
    var apuStateStruct: APUState?
    {
        get
        {
            guard let pulseStates: [PulseState] = (self.value(forKeyPath: "pulseStates") as? NSOrderedSet)?.compactMap({ ($0 as? NSManagedObject)?.pulseStateStruct }),
                  pulseStates.count >= 2,
                  let triangleState = (self.value(forKeyPath: "triangleState") as? NSManagedObject)?.triangleStateStruct,
                  let noiseState = (self.value(forKeyPath: "noiseState") as? NSManagedObject)?.noiseStateStruct,
                  let dmcState = (self.value(forKeyPath: "dmcState") as? NSManagedObject)?.dmcStateStruct
            else
            {
                return nil
            }
            
            let cycle: UInt64 = (self.value(forKeyPath: "cycle") as? Data)?.to(type: UInt64.self) ?? 0
            let framePeriod: UInt8 = (self.value(forKeyPath: "framePeriod") as? Data)?.to(type: UInt8.self) ?? 0
            let frameValue: UInt8 = (self.value(forKeyPath: "frameValue") as? Data)?.to(type: UInt8.self) ?? 0
            let frameIRQ: Bool = (self.value(forKeyPath: "frameIRQ") as? Bool) ?? false
            let audioBuffer: [Float32] = (self.value(forKeyPath: "audioBuffer") as? Data)?.toArray(type: Float32.self) ?? []
            let audioBufferIndex: UInt32 = (self.value(forKeyPath: "audioBufferIndex") as? Data)?.to(type: UInt32.self) ?? 0
            
            return APUState(cycle: cycle, framePeriod: framePeriod, frameValue: frameValue, frameIRQ: frameIRQ, audioBuffer: audioBuffer, audioBufferIndex: audioBufferIndex, pulse1: pulseStates[0], pulse2: pulseStates[1], triangle: triangleState, noise: noiseState, dmc: dmcState)
        }
        set
        {
            guard let safeNewValue = newValue else
            {
                return
            }
            self.setValue(Data.init(from: safeNewValue.cycle), forKeyPath: "cycle")
            self.setValue(Data.init(from: safeNewValue.framePeriod), forKeyPath: "framePeriod")
            self.setValue(Data.init(from: safeNewValue.frameValue), forKeyPath: "frameValue")
            self.setValue(safeNewValue.frameIRQ, forKey: "frameIRQ")
            self.setValue(Data.init(from: safeNewValue.audioBuffer), forKeyPath: "audioBuffer")
            self.setValue(Data.init(from: safeNewValue.audioBufferIndex), forKeyPath: "audioBufferIndex")
        }
    }
}
