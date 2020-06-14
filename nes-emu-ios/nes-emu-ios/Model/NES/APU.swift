//
//  APU.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/5/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

/// NES Audio Processing Unit
class APU
{
    weak var console: ConsoleProtocol?
    weak var cpu: CPUProtocol?
    weak var audioEngineDelegate: AudioEngineProtocol?
    private var audioBufferIndex: Int = 0
    private var audioBuffer: [Float32]
    private var sampleRate: SampleRate
    private var cycleSampleRate: Double
    private var pulse1: Pulse = Pulse(channel: 1)
    private var pulse2: Pulse = Pulse(channel: 2)
    private var triangle: Triangle = Triangle()
    private var noise: Noise = Noise()
    private var dmc: DMC = DMC()
    private var cycle: UInt64 = 0
    private var framePeriod: UInt8 = 0
    private var frameValue: UInt8 = 0
    private var frameIRQ: Bool = false
    private var filterChain: FilterChain
    
    static let frameCounterRate: Double = Double(CPU.frequency) / 240.0

    static let lengthTable: [UInt8] = [10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14, 12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30]
    
    var pulseTable: [Float32] = [Float32].init(repeating: 0, count: 31)
    var tndTable: [Float32] = [Float32].init(repeating: 0, count: 203)
    
    init(withSampleRate aSampleRate: SampleRate)
    {
        var pT: [Float32] = [Float32].init(repeating: 0, count: 31)
        var tT: [Float32] = [Float32].init(repeating: 0, count: 203)
        
        for i in 0 ..< 31
        {
            pT[i] = 95.52 / ((8128.0 / Float32(i)) + 100)
        }
        for i in 0 ..< 203
        {
            tT[i] = 163.67 / ((24329.0 / Float32(i)) + 100)
        }
        
        self.sampleRate = aSampleRate
        self.cycleSampleRate = Double(CPU.frequency) / aSampleRate.doubleValue
        self.audioBuffer = [Float32].init(repeating: 0.0, count: Int(aSampleRate.bufferCapacity))
        self.pulseTable = pT
        self.tndTable = tT
        self.pulse1 = Pulse(channel: 1)
        self.pulse2 = Pulse(channel: 2)
        self.filterChain = FilterChain(filters: [])
    }
    
    func step()
    {
        let cycle1 = self.cycle
        self.cycle += 1
        let cycle2 = self.cycle
        self.stepTimer()
        let f1 = Int(Double(cycle1) / APU.frameCounterRate)
        let f2 = Int(Double(cycle2) / APU.frameCounterRate)
        if f1 != f2
        {
            self.stepFrameCounter()
        }
        let s1 = Int(Double(cycle1) / self.cycleSampleRate)
        let s2 = Int(Double(cycle2) / self.cycleSampleRate)
        if s1 != s2
        {
            self.sendSample()
        }
    }

    func sendSample()
    {
        let output = self.output() //self.filterChain.step(x: self.output())
        self.audioBuffer[self.audioBufferIndex] = output
        self.audioBufferIndex += 1
        if self.audioBufferIndex >= self.audioBuffer.count
        {
            self.audioBufferIndex = 0
            self.audioEngineDelegate?.schedule(buffer: self.audioBuffer, withSampleRate: self.sampleRate)
        }
    }

    private func output() -> Float32
    {
        let p1 = self.pulse1.output()
        let p2 = self.pulse2.output()
        let t = self.triangle.output()
        let n = self.noise.output()
        let d = self.dmc.output()
        let pulseOut = pulseTable[Int(p1 + p2)]
        let tndOut = tndTable[Int((3 * t) + (2 * n) + d)]
        return pulseOut + tndOut
    }

    // mode 0:    mode 1:       function
    // ---------  -----------  -----------------------------
    //  - - - f    - - - - -    IRQ (if bit 6 is clear)
    //  - l - l    l - l - -    Length counter and sweep
    //  e e e e    e e e e -    Envelope and linear counter
    func stepFrameCounter()
    {
        switch self.framePeriod
        {
        case 4:
            self.frameValue = (self.frameValue + 1) % 4
            switch self.frameValue
            {
            case 0, 2:
                self.stepEnvelope()
            case 1:
                self.stepEnvelope()
                self.stepSweep()
                self.stepLength()
            case 3:
                self.stepEnvelope()
                self.stepSweep()
                self.stepLength()
                self.fireIRQ()
            default: break
            }
        case 5:
            self.frameValue = (self.frameValue + 1) % 5
            switch self.frameValue
            {
            case 0, 2:
                self.stepEnvelope()
            case 1, 3:
                self.stepEnvelope()
                self.stepSweep()
                self.stepLength()
            default: break
            }
        default: break
        }
    }

    func stepTimer()
    {
        if self.cycle % 2 == 0
        {
            self.pulse1.stepTimer()
            self.pulse2.stepTimer()
            self.noise.stepTimer()
            self.dmc.stepTimer(withCPU: self.cpu)
        }
        self.triangle.stepTimer()
    }

    func stepEnvelope()
    {
        self.pulse1.stepEnvelope()
        self.pulse2.stepEnvelope()
        self.triangle.stepCounter()
        self.noise.stepEnvelope()
    }

    func stepSweep()
    {
        self.pulse1.stepSweep()
        self.pulse2.stepSweep()
    }

    func stepLength()
    {
        self.pulse1.stepLength()
        self.pulse2.stepLength()
        self.triangle.stepLength()
        self.noise.stepLength()
    }

    func fireIRQ()
    {
        if self.frameIRQ
        {
            self.cpu?.triggerIRQ()
        }
    }

    func readRegister(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x4015:
            return self.readStatus()
        default: return 0
        }
    }

    func writeRegister(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress {
        case 0x4000:
            self.pulse1.writeControl(value: aValue)
        case 0x4001:
            self.pulse1.writeSweep(value: aValue)
        case 0x4002:
            self.pulse1.writeTimerLow(value: aValue)
        case 0x4003:
            self.pulse1.writeTimerHigh(value: aValue)
        case 0x4004:
            self.pulse2.writeControl(value: aValue)
        case 0x4005:
            self.pulse2.writeSweep(value: aValue)
        case 0x4006:
            self.pulse2.writeTimerLow(value: aValue)
        case 0x4007:
            self.pulse2.writeTimerHigh(value: aValue)
        case 0x4008:
            self.triangle.writeControl(value: aValue)
        case 0x4009, 0x4010:
            self.dmc.writeControl(value: aValue)
        case 0x4011:
            self.dmc.writeValue(value: aValue)
        case 0x4012:
            self.dmc.writeAddress(value: aValue)
        case 0x4013:
            self.dmc.writeLength(value: aValue)
        case 0x400A:
            self.triangle.writeTimerLow(value: aValue)
        case 0x400B:
            self.triangle.writeTimerHigh(value: aValue)
        case 0x400C:
            self.noise.writeControl(value: aValue)
        case 0x400D, 0x400E:
            self.noise.writePeriod(value: aValue)
        case 0x400F:
            self.noise.writeLength(value: aValue)
        case 0x4015:
            self.writeControl(value: aValue)
        case 0x4017:
            self.writeFrameCounter(value: aValue)
        default: break
        }
    }

    func readStatus() -> UInt8
    {
        var result: UInt8 = 0
        if self.pulse1.lengthValue > 0
        {
            result |= 1
        }
        
        if self.pulse2.lengthValue > 0
        {
            result |= 2
        }
        
        if self.triangle.lengthValue > 0
        {
            result |= 4
        }
        
        if self.noise.lengthValue > 0
        {
            result |= 8
        }
        
        if self.dmc.currentLength > 0
        {
            result |= 16
        }
        
        return result
    }

    func writeControl(value aValue: UInt8)
    {
        self.pulse1.enabled = aValue & 1 == 1
        self.pulse2.enabled = aValue & 2 == 2
        self.triangle.enabled = aValue & 4 == 4
        self.noise.enabled = aValue & 8 == 8
        self.dmc.enabled = aValue & 16 == 16
        
        if !self.pulse1.enabled
        {
            self.pulse1.lengthValue = 0
        }
        
        if !self.pulse2.enabled
        {
            self.pulse2.lengthValue = 0
        }
        
        if !self.triangle.enabled
        {
            self.triangle.lengthValue = 0
        }
        
        if !self.noise.enabled
        {
            self.noise.lengthValue = 0
        }
        
        if !self.dmc.enabled
        {
            self.dmc.currentLength = 0
        }
        else
        {
            if self.dmc.currentLength == 0
            {
                self.dmc.restart()
            }
        }
    }

    func writeFrameCounter(value aValue: UInt8)
    {
        self.framePeriod = 4 + (aValue >> 7) & 1
        self.frameIRQ = (aValue >> 6) & 1 == 0
        if self.framePeriod == 5
        {
            self.stepEnvelope()
            self.stepSweep()
            self.stepLength()
        }
    }
    
    /// sampleRate: samples per second cutoffFreq: oscillations per second
    private func lowPassFilter(sampleRate aSampleRate: Float32, cutoffFreq aCutoffFreq: Float32) -> Filter
    {
        let c = aSampleRate / Float32.pi / aCutoffFreq
        let a0i = 1 / (1 + c)
        return FirstOrderFilter(B0: a0i, B1: a0i, A1: (1 - c) * a0i, prevX: 0, prevY: 0)
    }

    /// sampleRate: samples per second cutoffFreq: oscillations per second
    private func highPassFilter(sampleRate aSampleRate: Float32, cutoffFreq aCutoffFreq: Float32) -> Filter
    {
        let c = aSampleRate / Float32.pi / aCutoffFreq
        let a0i = 1 / (1 + c)
        return FirstOrderFilter(B0: c * a0i, B1: -1.0 * c * a0i, A1: (1 - c) * a0i, prevX: 0, prevY: 0)
    }
    
    // MARK: - Channel Structs
    
    struct Pulse
    {
        var channel: UInt8
        var enabled: Bool = false
        var lengthEnabled: Bool = false
        var lengthValue: UInt8 = 0
        var timerPeriod: UInt16 = 0
        var timerValue: UInt16 = 0
        var dutyMode: UInt8 = 0
        var dutyValue: UInt8 = 0
        var sweepReload: Bool = false
        var sweepEnabled: Bool = false
        var sweepNegate: Bool = false
        var sweepShift: UInt8 = 0
        var sweepPeriod: UInt8 = 0
        var sweepValue: UInt8 = 0
        var envelopeEnabled: Bool = false
        var envelopeLoop: Bool = false
        var envelopeStart: Bool = false
        var envelopePeriod: UInt8 = 0
        var envelopeValue:  UInt8 = 0
        var envelopeVolume: UInt8 = 0
        var constantVolume: UInt8 = 0
        
        static let dutyTable: [[UInt8]] =
        [[0, 1, 0, 0, 0, 0, 0, 0],
         [0, 1, 1, 0, 0, 0, 0, 0],
         [0, 1, 1, 1, 1, 0, 0, 0],
         [1, 0, 0, 1, 1, 1, 1, 1]]
        
        mutating func writeControl(value aValue: UInt8)
        {
            self.dutyMode = (aValue >> 6) & 3
            self.lengthEnabled = (aValue >> 5) & 1 == 0
            self.envelopeLoop = (aValue >> 5) & 1 == 1
            self.envelopeEnabled = (aValue >> 4) & 1 == 0
            self.envelopePeriod = aValue & 15
            self.constantVolume = aValue & 15
            self.envelopeStart = true
        }

        mutating func writeSweep(value aValue: UInt8)
        {
            self.sweepEnabled = (aValue >> 7) & 1 == 1
            self.sweepPeriod = ((aValue >> 4) & 7) + 1
            self.sweepNegate = (aValue >> 3) & 1 == 1
            self.sweepShift = aValue & 7
            self.sweepReload = true
        }

        mutating func writeTimerLow(value aValue: UInt8)
        {
            self.timerPeriod = (self.timerPeriod & 0xFF00) | UInt16(aValue)
        }

        mutating func writeTimerHigh(value aValue: UInt8)
        {
            self.lengthValue = APU.lengthTable[Int(aValue >> 3)]
            self.timerPeriod = (self.timerPeriod & 0x00FF) | (UInt16(aValue & 7) << 8)
            self.envelopeStart = true
            self.dutyValue = 0
        }

        mutating func stepTimer()
        {
            if self.timerValue == 0
            {
                self.timerValue = self.timerPeriod
                self.dutyValue = (self.dutyValue + 1) % 8
            }
            else
            {
                self.timerValue -= 1
            }
        }

        mutating func stepEnvelope()
        {
            if self.envelopeStart
            {
                self.envelopeVolume = 15
                self.envelopeValue = self.envelopePeriod
                self.envelopeStart = false
            }
            else if self.envelopeValue > 0
            {
                self.envelopeValue -= 1
            }
            else
            {
                if self.envelopeVolume > 0
                {
                    self.envelopeVolume -= 1
                }
                else if self.envelopeLoop
                {
                    self.envelopeVolume = 15
                }
                
                self.envelopeValue = self.envelopePeriod
            }
        }

        mutating func stepSweep()
        {
            if self.sweepReload
            {
                if self.sweepEnabled && self.sweepValue == 0
                {
                    self.sweep()
                }
                self.sweepValue = self.sweepPeriod
                self.sweepReload = false
            }
            else if self.sweepValue > 0
            {
                self.sweepValue -= 1
            }
            else
            {
                if self.sweepEnabled
                {
                    self.sweep()
                }
                self.sweepValue = self.sweepPeriod
            }
        }

        mutating func stepLength()
        {
            if self.lengthEnabled && self.lengthValue > 0
            {
                self.lengthValue -= 1
            }
        }

        mutating func sweep()
        {
            let delta = self.timerPeriod >> self.sweepShift
            if self.sweepNegate
            {
                self.timerPeriod -= delta
                if self.channel == 1
                {
                    self.timerPeriod -= 1
                }
            }
            else
            {
                self.timerPeriod += delta
            }
        }

        func output() -> UInt8
        {
            if !self.enabled
            {
                return 0
            }
            
            if self.lengthValue == 0
            {
                return 0
            }
            
            if Pulse.dutyTable[Int(self.dutyMode)][Int(self.dutyValue)] == 0
            {
                return 0
            }
            
            if self.timerPeriod < 8 || self.timerPeriod > 0x7FF
            {
                return 0
            }

            if self.envelopeEnabled
            {
                return self.envelopeVolume
            }
            else
            {
                return self.constantVolume
            }
        }
    }
    
    struct Triangle
    {
        static let triangleTable: [UInt8] = [
            15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
            0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        ]
        
        var enabled: Bool = false
        var lengthEnabled: Bool = false
        var lengthValue: UInt8 = 0
        var timerPeriod: UInt16 = 0
        var timerValue: UInt16 = 0
        var dutyValue: UInt8 = 0
        var counterPeriod: UInt8 = 0
        var counterValue: UInt8 = 0
        var counterReload: Bool = false
        
        mutating func writeControl(value aValue: UInt8)
        {
            self.lengthEnabled = (aValue >> 7) & 1 == 0
            self.counterPeriod = aValue & 0x7F
        }

        mutating func writeTimerLow(value aValue: UInt8)
        {
            self.timerPeriod = (self.timerPeriod & 0xFF00) | UInt16(aValue)
        }

        mutating func writeTimerHigh(value aValue: UInt8)
        {
            self.lengthValue = APU.lengthTable[Int(aValue >> 3)]
            self.timerPeriod = (self.timerPeriod & 0x00FF) | (UInt16(aValue & 7) << 8)
            self.timerValue = self.timerPeriod
            self.counterReload = true
        }

        mutating func stepTimer()
        {
            if self.timerValue == 0
            {
                self.timerValue = self.timerPeriod
                if self.lengthValue > 0 && self.counterValue > 0
                {
                    self.dutyValue = (self.dutyValue + 1) % 32
                }
            }
            else
            {
                self.timerValue -= 1
            }
        }

        mutating func stepLength()
        {
            if self.lengthEnabled && self.lengthValue > 0
            {
                self.lengthValue -= 1
            }
        }

        mutating func stepCounter()
        {
            if self.counterReload
            {
                self.counterValue = self.counterPeriod
            }
            else if self.counterValue > 0
            {
                self.counterValue -= 1
            }
            
            if self.lengthEnabled
            {
                self.counterReload = false
            }
        }

        func output() -> UInt8
        {
            if !self.enabled
            {
                return 0
            }
            
            if self.lengthValue == 0
            {
                return 0
            }
            
            if self.counterValue == 0
            {
                return 0
            }
            
            return Triangle.triangleTable[Int(self.dutyValue)]
        }
    }
    
    struct Noise
    {
        var enabled: Bool = false
        var mode: Bool = false
        var shiftRegister: UInt16 = 1
        var lengthEnabled: Bool = false
        var lengthValue: UInt8 = 0
        var timerPeriod: UInt16 = 0
        var timerValue: UInt16 = 0
        var envelopeEnabled: Bool = false
        var envelopeLoop: Bool = false
        var envelopeStart: Bool = false
        var envelopePeriod: UInt8 = 0
        var envelopeValue: UInt8 = 0
        var envelopeVolume: UInt8 = 0
        var constantVolume: UInt8 = 0
        
        static let noiseTable: [UInt16] = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
        
        mutating func writeControl(value aValue: UInt8)
        {
            self.lengthEnabled = (aValue >> 5) & 1 == 0
            self.envelopeLoop = (aValue >> 5) & 1 == 1
            self.envelopeEnabled = (aValue >> 4) & 1 == 0
            self.envelopePeriod = aValue & 15
            self.constantVolume = aValue & 15
            self.envelopeStart = true
        }

        mutating func writePeriod(value aValue: UInt8)
        {
            self.mode =  aValue & 0x80 == 0x80
            self.timerPeriod = Noise.noiseTable[Int(aValue & 0x0F)]
        }

        mutating func writeLength(value aValue: UInt8)
        {
            self.lengthValue = APU.lengthTable[Int(aValue >> 3)]
            self.envelopeStart = true
        }

        mutating func stepTimer()
        {
            if self.timerValue == 0
            {
                self.timerValue = self.timerPeriod
                let shift: UInt8
                if self.mode
                {
                    shift = 6
                }
                else
                {
                    shift = 1
                }
                
                let b1 = self.shiftRegister & 1
                let b2 = (self.shiftRegister >> shift) & 1
                self.shiftRegister >>= 1
                self.shiftRegister |= (b1 ^ b2) << 14
            }
            else
            {
                self.timerValue -= 1
            }
        }

        mutating func stepEnvelope()
        {
            if self.envelopeStart
            {
                self.envelopeVolume = 15
                self.envelopeValue = self.envelopePeriod
                self.envelopeStart = false
            }
            else if self.envelopeValue > 0
            {
                self.envelopeValue -= 1
            }
            else
            {
                if self.envelopeVolume > 0
                {
                    self.envelopeVolume -= 1
                }
                else if self.envelopeLoop
                {
                    self.envelopeVolume = 15
                }
                self.envelopeValue = self.envelopePeriod
            }
        }

        mutating func stepLength()
        {
            if self.lengthEnabled && self.lengthValue > 0
            {
                self.lengthValue -= 1
            }
        }

        func output() -> UInt8
        {
            if !self.enabled
            {
                return 0
            }
            
            if self.lengthValue == 0
            {
                return 0
            }
            
            if self.shiftRegister & 1 == 1
            {
                return 0
            }
            
            if self.envelopeEnabled
            {
                return self.envelopeVolume
            }
            else
            {
                return self.constantVolume
            }
        }
    }
    
    struct DMC
    {
        var enabled: Bool = false
        var value: UInt8 = 0
        var sampleAddress: UInt16 = 0
        var sampleLength: UInt16 = 0
        var currentAddress: UInt16 = 0
        var currentLength: UInt16 = 0
        var shiftRegister: UInt8 = 0
        var bitCount: UInt8 = 0
        var tickPeriod: UInt8 = 0
        var tickValue: UInt8 = 0
        var loop: Bool = false
        var irq: Bool = false
        
        static let dmcTable: [UInt8] = [214, 190, 170, 160, 143, 127, 113, 107, 95, 80, 71, 64, 53, 42, 36, 27]
        
        mutating func writeControl(value aValue: UInt8)
        {
            self.irq = aValue & 0x80 == 0x80
            self.loop = aValue & 0x40 == 0x40
            self.tickPeriod = DMC.dmcTable[Int(aValue & 0x0F)]
        }

        mutating func writeValue(value aValue: UInt8)
        {
            self.value = aValue & 0x7F
        }

        mutating func writeAddress(value aValue: UInt8)
        {
            // Sample address = %11AAAAAA.AA000000
            self.sampleAddress = 0xC000 | (UInt16(aValue) << 6)
        }

        mutating func writeLength(value aValue: UInt8)
        {
            // Sample length = %0000LLLL.LLLL0001
            self.sampleLength = (UInt16(value) << 4) | 1
        }

        mutating func restart()
        {
            self.currentAddress = self.sampleAddress
            self.currentLength = self.sampleLength
        }

        mutating func stepTimer(withCPU aCPU: CPUProtocol?)
        {
            if !self.enabled
            {
                return
            }
            
            self.stepReader(withCPU: aCPU)
            
            if self.tickValue == 0
            {
                self.tickValue = self.tickPeriod
                self.stepShifter()
            }
            else
            {
                self.tickValue -= 1
            }
        }

        mutating func stepReader(withCPU aCPU: CPUProtocol?)
        {
            guard let safeCPU = aCPU else { return }
            
            if self.currentLength > 0 && self.bitCount == 0
            {
                safeCPU.stall += 4
                self.shiftRegister = safeCPU.read(address: self.currentAddress)
                self.bitCount = 8
                self.currentAddress += 1
                
                if self.currentAddress == 0
                {
                    self.currentAddress = 0x8000
                }
                
                self.currentLength -= 1
                
                if self.currentLength == 0 && self.loop
                {
                    self.restart()
                }
            }
        }

        mutating func stepShifter()
        {
            if self.bitCount == 0
            {
                return
            }
            
            if self.shiftRegister&1 == 1
            {
                if self.value <= 125
                {
                    self.value += 2
                }
            }
            else
            {
                if self.value >= 2
                {
                    self.value -= 2
                }
            }
            
            self.shiftRegister >>= 1
            self.bitCount -= 1
        }

        func output() -> UInt8
        {
            return self.value
        }
    }
}
