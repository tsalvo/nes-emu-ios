//
//  Console.swift
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

struct Console
{
    private(set) var cpu: CPU
    
    init(withCartridge aCartridge: Cartridge, sampleRate aSampleRate: SampleRate, audioFiltersEnabled aAudioFiltersEnabled: Bool)
    {
        self.cpu = CPU(ppu: PPU(mapper: aCartridge.mapper), apu: APU(withSampleRate: aSampleRate, filtersEnabled: aAudioFiltersEnabled), controllers: [Controller(), Controller()])
    }
    
    mutating func set(audioEngineDelegate aAudioEngineDelegate: AudioEngineProtocol?)
    {
        self.cpu.apu.audioEngineDelegate = aAudioEngineDelegate
    }
    
    mutating func set(button aButton: ControllerButton, enabled aEnabled: Bool, forControllerAtIndex aIndex: Int)
    {
        guard aIndex < self.cpu.controllers.count else { return }
        self.cpu.controllers[aIndex].set(buttonAtIndex: aButton.rawValue, enabled: aEnabled)
    }
    
    /// set all buttons at once for a given controller
    mutating func set(buttonUpPressed aButtonUpPressed: Bool, buttonDownPressed aButtonDownPressed: Bool, buttonLeftPressed aButtonLeftPressed: Bool, buttonRightPressed aButtonRightPressed: Bool, buttonSelectPressed aButtonSelectPressed: Bool, buttonStartPressed aButtonStartPressed: Bool, buttonBPressed aButtonBPressed: Bool, buttonAPressed aButtonAPressed: Bool, forControllerAtIndex aIndex: Int)
    {
        guard aIndex < self.cpu.controllers.count else { return }
        self.cpu.controllers[aIndex].set(buttons: [aButtonAPressed, aButtonBPressed, aButtonSelectPressed, aButtonStartPressed, aButtonUpPressed, aButtonDownPressed, aButtonLeftPressed, aButtonRightPressed])
    }
    
    mutating func reset()
    {
        self.cpu.reset()
    }
    
    mutating func stepSeconds(seconds aSeconds: Float64)
    {
        var cycles = Int(Float64(CPU.frequency) * aSeconds)
        while cycles > 0
        {
            cycles -= self.step()
        }
    }
    
    private mutating func step() -> Int
    {
        let cpuCycles = self.cpu.step()
        return cpuCycles
    }
}
