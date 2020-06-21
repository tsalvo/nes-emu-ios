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

protocol ConsoleProtocol: class
{
    var cpu: CPU { get }
}

class Console: ConsoleProtocol
{
    let apu: APU
    let ppu: PPU
    let cpu: CPU
    let cartridge: Cartridge
    let controllers: [Controller]
    let queue: DispatchQueue
    
    init(withCartridge aCartridge: Cartridge, sampleRate aSampleRate: SampleRate, audioFiltersEnabled aAudioFiltersEnabled: Bool)
    {
        self.queue = DispatchQueue(label: "ConsoleQueue", qos: .userInteractive)
        let apu = APU(withSampleRate: aSampleRate, filtersEnabled: aAudioFiltersEnabled)
        let controllers: [Controller] = [Controller(), Controller()]
        let mapper = aCartridge.mapper
        let ppu = PPU(mapper: mapper)
        let cpu = CPU(ppu: ppu, apu: apu, mapper: mapper, controller1: controllers[0], controller2: controllers[1])
        self.cpu = cpu
        self.apu = apu
        self.ppu = ppu
        self.cartridge = aCartridge
        self.controllers = controllers
        self.ppu.cpu = cpu
        self.apu.cpu = cpu
    }
    
    func set(audioEngineDelegate aAudioEngineDelegate: AudioEngineProtocol?)
    {
        self.queue.async { [weak self] in
            self?.apu.audioEngineDelegate = aAudioEngineDelegate
        }
    }
    
    func set(button aButton: ControllerButton, enabled aEnabled: Bool, forControllerAtIndex aIndex: Int)
    {
        self.queue.async { [weak self] in
            guard aIndex < self?.controllers.count ?? Int.max else { return }
            self?.controllers[aIndex].set(buttonAtIndex: aButton.rawValue, enabled: aEnabled)
        }
    }
    
    /// set all buttons at once for a given controller
    func set(buttonUpPressed aButtonUpPressed: Bool, buttonDownPressed aButtonDownPressed: Bool, buttonLeftPressed aButtonLeftPressed: Bool, buttonRightPressed aButtonRightPressed: Bool, buttonSelectPressed aButtonSelectPressed: Bool, buttonStartPressed aButtonStartPressed: Bool, buttonBPressed aButtonBPressed: Bool, buttonAPressed aButtonAPressed: Bool, forControllerAtIndex aIndex: Int)
    {
        self.queue.async { [weak self] in
            guard aIndex < self?.controllers.count ?? Int.max else { return }
            self?.controllers[aIndex].set(buttons: [aButtonAPressed, aButtonBPressed, aButtonSelectPressed, aButtonStartPressed, aButtonUpPressed, aButtonDownPressed, aButtonLeftPressed, aButtonRightPressed])
        }
    }
    
    func reset(completionHandler aCompletionHandler: (() -> Void)?)
    {
        self.queue.async { [weak self] in
            
            self?.cpu.reset()
            self?.ppu.reset()
            
            DispatchQueue.main.async {
                aCompletionHandler?()
            }
        }
    }
    
    func stepSeconds(seconds aSeconds: Float64, completionHandler aCompletionHandler: (() -> Void)?)
    {
        self.queue.async { [weak self] in
            
            var cycles = Int(Float64(CPU.frequency) * aSeconds)
            while cycles > 0
            {
                cycles -= self?.step() ?? cycles
            }
            
            DispatchQueue.main.async {
                aCompletionHandler?()
            }
        }
    }
    
    private func step() -> Int
    {
        let cpuCycles = self.cpu.step()
        let ppuCycles = cpuCycles * 3
        
        for _ in 0 ..< ppuCycles
        {
            self.ppu.step(cpu: self.cpu)
        }
        
        for _ in 0 ..< cpuCycles
        {
            self.apu.step()
        }
        
        return cpuCycles
    }
    
    private func stepFrame() -> Int
    {
        var cpuCycles = 0
        let frame = self.ppu.frame
        while frame == self.ppu.frame
        {
            cpuCycles += self.step()
        }
        return cpuCycles
    }
}
