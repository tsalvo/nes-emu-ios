//
//  NSManagedObject+APUState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

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
