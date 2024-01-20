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
    // MARK: - Private Variables
    private let md5: String /// game MD5 hash
    private var cpu: CPU
    
    // MARK: - Computed Properties
    /// returns a 256x224 array of palette colors copies from the PPU's current screen buffer
    var screenBuffer: [UInt32]
    {
        get {
            self.cpu.ppu.frontBuffer
        }
        set {
            
        }
    }
    
    /// returns a ConsoleState struct containing the current state of the CPU, PPU, APU, and Mapper
    func consoleState(isAutoSave aIsAutosave: Bool) -> ConsoleState
    {
        ConsoleState(isAutoSave: aIsAutosave, date: Date(), md5: self.md5, cpuState: self.cpu.cpuState, apuState: self.cpu.apu.apuState, ppuState: self.cpu.ppu.ppuState, mapperState: self.cpu.ppu.mapper.mapperState)
    }
    
    // MARK: - Life cycle
    init(withCartridge aCartridge: Cartridge, sampleRate aSampleRate: SampleRate, audioFiltersEnabled aAudioFiltersEnabled: Bool, state aState: ConsoleState? = nil)
    {
        self.md5 = aCartridge.md5
        self.cpu = CPU(ppu: PPU(mapper: aCartridge.mapper(withState: aState?.mapperState), state: aState?.ppuState), apu: APU(withSampleRate: aSampleRate, filtersEnabled: aAudioFiltersEnabled, state: aState?.apuState), controllers: [Controller(), Controller()], state: aState?.cpuState)
    }
    
    // MARK: - Audio
    mutating func set(audioEngineDelegate aAudioEngineDelegate: AudioEngineProtocol?)
    {
        self.cpu.apu.audioEngineDelegate = aAudioEngineDelegate
    }
    
    // MARK: - Buttons
    
    /// set an individual button to on or off for fontroller 0 or 1
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
    
    /// reset the console and restart the currently-loaded game
    mutating func reset()
    {
        self.cpu.reset()
    }
    
    mutating func load(state aState: ConsoleState)
    {
        let sampleRate: SampleRate = self.cpu.apu.sampleRate
        let filtersEnabled: Bool = self.cpu.apu.filtersEnabled
        var mapper = self.cpu.ppu.mapper
        mapper.mapperState = aState.mapperState
        
        self.cpu = CPU(ppu: PPU(mapper: mapper, state: aState.ppuState), apu: APU(withSampleRate: sampleRate, filtersEnabled: filtersEnabled, state: aState.apuState), controllers: [Controller(), Controller()], state: aState.cpuState)
    }
    
    // MARK: - Timing
    
    mutating func stepSeconds(seconds aSeconds: Float64)
    {
        var cycles = Int(Float64(CPU.frequency) * aSeconds)
        while cycles > 0
        {
            cycles -= self.cpu.step()
        }
    }
}
