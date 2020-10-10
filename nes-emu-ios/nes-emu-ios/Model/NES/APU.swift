//
//  APU.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/5/20.
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

struct APUStepResults
{
    let shouldTriggerIRQOnCPU: Bool
    let numCPUStallCycles: UInt64
}

/// NES Audio Processing Unit
struct APU
{
    weak var audioEngineDelegate: AudioEngineProtocol?
    private var audioBufferIndex: Int = 0
    private var audioBuffer: [Float32]
    private(set) var sampleRate: SampleRate
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
    var filtersEnabled: Bool { return self.filterChain.filters.count > 0}
    var dmcCurrentAddress: UInt16 { return self.dmc.currentAddress }
    
    static let frameCounterRate: Double = Double(CPU.frequency) / 240.0

    static let lengthTable: [UInt8] = [10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14, 12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30]
    
    /// pulseTable[i] = 95.52 / ((8128.0 / Float32(i)) + 100)
    private static let pulseTable: [Float32] = [0.0, 0.011609139, 0.02293948, 0.034000948, 0.044803, 0.05535466, 0.06566453, 0.07574082, 0.0855914, 0.09522375, 0.10464504, 0.11386215, 0.12288164, 0.1317098, 0.14035264, 0.14881596, 0.15710525, 0.16522588, 0.17318292, 0.18098126, 0.18862559, 0.19612046, 0.20347017, 0.21067894, 0.21775076, 0.2246895, 0.23149887, 0.23818247, 0.24474378, 0.25118607, 0.25751257]
    
    /// tndTable[i] = 163.67 / ((24329.0 / Float32(i)) + 100)
    private static let tndTable: [Float32] = [0.0, 0.006699824, 0.01334502, 0.019936256, 0.02647418, 0.032959443, 0.039392676, 0.0457745, 0.052105535, 0.05838638, 0.064617634, 0.07079987, 0.07693369, 0.08301962, 0.08905826, 0.095050134, 0.100995794, 0.10689577, 0.11275058, 0.118560754, 0.12432679, 0.13004918, 0.13572845, 0.14136505, 0.1469595, 0.15251222, 0.1580237, 0.1634944, 0.16892476, 0.17431524, 0.17966628, 0.1849783, 0.19025174, 0.19548698, 0.20068447, 0.20584463, 0.21096781, 0.21605444, 0.22110492, 0.2261196, 0.23109888, 0.23604311, 0.24095272, 0.245828, 0.25066936, 0.2554771, 0.26025164, 0.26499328, 0.26970237, 0.27437922, 0.27902418, 0.28363758, 0.28821972, 0.29277095, 0.29729152, 0.3017818, 0.3062421, 0.31067267, 0.31507385, 0.31944588, 0.32378912, 0.32810378, 0.3323902, 0.3366486, 0.3408793, 0.34508255, 0.34925863, 0.35340777, 0.35753027, 0.36162636, 0.36569634, 0.36974037, 0.37375876, 0.37775174, 0.38171956, 0.38566244, 0.38958064, 0.39347437, 0.39734384, 0.4011893, 0.405011, 0.40880907, 0.41258383, 0.41633546, 0.42006415, 0.42377013, 0.4274536, 0.43111476, 0.43475384, 0.43837097, 0.44196644, 0.4455404, 0.449093, 0.45262453, 0.45613506, 0.4596249, 0.46309412, 0.46654293, 0.46997157, 0.47338015, 0.47676894, 0.48013794, 0.48348752, 0.4868177, 0.49012873, 0.4934207, 0.49669388, 0.49994832, 0.50318426, 0.50640184, 0.5096012, 0.51278245, 0.51594585, 0.5190914, 0.5222195, 0.52533007, 0.52842325, 0.5314993, 0.53455836, 0.5376005, 0.54062593, 0.5436348, 0.54662704, 0.54960304, 0.55256283, 0.55550647, 0.5584343, 0.56134623, 0.5642425, 0.56712323, 0.5699885, 0.5728384, 0.5756732, 0.57849294, 0.5812977, 0.5840876, 0.5868628, 0.58962345, 0.59236956, 0.59510136, 0.5978189, 0.6005223, 0.6032116, 0.605887, 0.60854864, 0.6111966, 0.6138308, 0.61645156, 0.619059, 0.62165314, 0.624234, 0.62680185, 0.6293567, 0.63189864, 0.6344277, 0.6369442, 0.63944805, 0.64193934, 0.64441824, 0.64688486, 0.6493392, 0.6517814, 0.6542115, 0.65662974, 0.65903604, 0.6614306, 0.6638134, 0.66618466, 0.66854435, 0.6708926, 0.67322946, 0.67555505, 0.67786944, 0.68017274, 0.68246496, 0.6847462, 0.6870166, 0.6892762, 0.69152504, 0.6937633, 0.6959909, 0.69820803, 0.7004148, 0.7026111, 0.7047972, 0.7069731, 0.7091388, 0.7112945, 0.7134401, 0.7155759, 0.7177018, 0.7198179, 0.72192425, 0.72402096, 0.726108, 0.72818565, 0.7302538, 0.73231256, 0.73436195, 0.7364021, 0.7384331, 0.7404549, 0.7424676]
    
    init(withSampleRate aSampleRate: SampleRate, filtersEnabled aFiltersEnabled: Bool, state aState: APUState? = nil)
    {
        self.sampleRate = aSampleRate
        self.cycleSampleRate = Double(CPU.frequency) / aSampleRate.doubleValue
        self.audioBuffer = [Float32].init(repeating: 0.0, count: Int(aSampleRate.bufferCapacity))
        self.pulse1 = Pulse(channel: 1)
        self.pulse2 = Pulse(channel: 2)
        self.filterChain = FilterChain(filters: aFiltersEnabled ? [
            APU.highPassFilter(sampleRate: aSampleRate.floatValue, cutoffFreq: 90),
            APU.highPassFilter(sampleRate: aSampleRate.floatValue, cutoffFreq: 440),
            APU.lowPassFilter(sampleRate: aSampleRate.floatValue, cutoffFreq: 14000),
            ] : [])
    }
    
    var apuState: APUState
    {
        return APUState()
    }
    
    mutating func step(dmcCurrentAddressValue aDmcCurrentAddressValue: UInt8) -> APUStepResults
    {
        let shouldFireIRQ: Bool
        let cycle1 = self.cycle
        self.cycle += 1
        let cycle2 = self.cycle
        let numCPUStallCycles: UInt64 = self.stepTimer(dmcCurrentAddressValue: aDmcCurrentAddressValue)
        let f1 = Int(Double(cycle1) / APU.frameCounterRate)
        let f2 = Int(Double(cycle2) / APU.frameCounterRate)
        if f1 != f2
        {
            shouldFireIRQ = self.stepFrameCounter()
        }
        else
        {
            shouldFireIRQ = false
        }
        let s1 = Int(Double(cycle1) / self.cycleSampleRate)
        let s2 = Int(Double(cycle2) / self.cycleSampleRate)
        if s1 != s2
        {
            self.sendSample()
        }
        
        return APUStepResults(shouldTriggerIRQOnCPU: shouldFireIRQ, numCPUStallCycles: numCPUStallCycles)
    }

    mutating func sendSample()
    {
        let output = self.filterChain.step(x: self.output())
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
        let pulseOut = APU.pulseTable[Int(p1 + p2)]
        let tndOut = APU.tndTable[Int((3 * t) + (2 * n) + d)]
        return pulseOut + tndOut
    }

    // mode 0:    mode 1:       function
    // ---------  -----------  -----------------------------
    //  - - - f    - - - - -    IRQ (if bit 6 is clear)
    //  - l - l    l - l - -    Length counter and sweep
    //  e e e e    e e e e -    Envelope and linear counter
    mutating func stepFrameCounter() -> Bool
    {
        var shouldFireIRQ: Bool = false
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
                if self.frameIRQ
                {
                    shouldFireIRQ = true
                }
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
        
        return shouldFireIRQ
    }

    mutating func stepTimer(dmcCurrentAddressValue aDmcCurrentAddressValue: UInt8) -> UInt64
    {
        let numCPUStallCycles: UInt64
        if self.cycle % 2 == 0
        {
            self.pulse1.stepTimer()
            self.pulse2.stepTimer()
            self.noise.stepTimer()
            numCPUStallCycles = self.dmc.stepTimer(dmcCurrentAddressValue: aDmcCurrentAddressValue)
        }
        else
        {
            numCPUStallCycles = 0
        }
        self.triangle.stepTimer()
        
        return numCPUStallCycles
    }

    mutating func stepEnvelope()
    {
        self.pulse1.stepEnvelope()
        self.pulse2.stepEnvelope()
        self.triangle.stepCounter()
        self.noise.stepEnvelope()
    }

    mutating func stepSweep()
    {
        self.pulse1.stepSweep()
        self.pulse2.stepSweep()
    }

    mutating func stepLength()
    {
        self.pulse1.stepLength()
        self.pulse2.stepLength()
        self.triangle.stepLength()
        self.noise.stepLength()
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

    mutating func writeRegister(address aAddress: UInt16, value aValue: UInt8)
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

    mutating func writeControl(value aValue: UInt8)
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

    mutating func writeFrameCounter(value aValue: UInt8)
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
    private static func lowPassFilter(sampleRate aSampleRate: Float32, cutoffFreq aCutoffFreq: Float32) -> Filter
    {
        let c = aSampleRate / Float32.pi / aCutoffFreq
        let a0i = 1 / (1 + c)
        return FirstOrderFilter(B0: a0i, B1: a0i, A1: (1 - c) * a0i, prevX: 0, prevY: 0)
    }

    /// sampleRate: samples per second cutoffFreq: oscillations per second
    private static func highPassFilter(sampleRate aSampleRate: Float32, cutoffFreq aCutoffFreq: Float32) -> Filter
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
                self.timerPeriod &+= delta
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
            if !self.enabled || self.lengthValue == 0 || self.counterValue == 0
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
                let shift: UInt8 = self.mode ? 6 : 1
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
            if !self.enabled || self.lengthValue == 0 || self.shiftRegister & 1 == 1
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

        mutating func stepTimer(dmcCurrentAddressValue aDmcCurrentAddressValue: UInt8) -> UInt64
        {
            if !self.enabled
            {
                return 0
            }
            
            let numCPUStallCycles: UInt64 = self.stepReader(dmcCurrentAddressValue: aDmcCurrentAddressValue)
            
            if self.tickValue == 0
            {
                self.tickValue = self.tickPeriod
                self.stepShifter()
            }
            else
            {
                self.tickValue -= 1
            }
            
            return numCPUStallCycles
        }

        mutating func stepReader(dmcCurrentAddressValue aDmcCurrentAddressValue: UInt8) -> UInt64
        {
            let numCPUStallCycles: UInt64
            if self.currentLength > 0 && self.bitCount == 0
            {
                numCPUStallCycles = 4
                self.shiftRegister = aDmcCurrentAddressValue
                self.bitCount = 8
                self.currentAddress &+= 1
                
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
            else
            {
                numCPUStallCycles = 0
            }
            
            return numCPUStallCycles
        }

        mutating func stepShifter()
        {
            if self.bitCount == 0
            {
                return
            }
            
            if self.shiftRegister & 1 == 1
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
