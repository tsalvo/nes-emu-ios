//
//  Console.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/5/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

protocol ConsoleProtocol: class
{
    var cpu: CPU { get }
}

class Console: ConsoleProtocol
{
    let mapper: MapperProtocol?
    let apu: APU
    let ppu: PPU
    let cpu: CPU
    let cartridge: Cartridge
    let controllers: [Controller] = [Controller(index: 0), Controller(index: 1)]
    
    init(withCartridge aCartridge: Cartridge)
    {
        let apu = APU()
        let mapper = aCartridge.mapperIdentifier.mapper(forCartridge: aCartridge)
        let ppu = PPU(cartridge: aCartridge, mapper: mapper)
        self.cpu = CPU(ppu: ppu, apu: apu, mapper: mapper)
        self.apu = apu
        self.ppu = ppu
        self.cartridge = aCartridge
        self.mapper = mapper
        self.cpu.console = self
        self.apu.console = self
        self.ppu.console = self
    }
    
    func reset()
    {
        self.cpu.reset()
        self.ppu.reset()
    }
    
    func step() -> Int
    {
        let cpuCycles = self.cpu.step()
        let ppuCycles = cpuCycles * 3
        
        for _ in 0 ..< ppuCycles
        {
            self.ppu.step()
            self.mapper?.step()
        }
        
        for _ in 0 ..< cpuCycles
        {
            self.apu.step()
        }
        
        return cpuCycles
    }
    
    func stepFrame() -> Int
    {
        var cpuCycles = 0
        let frame = self.ppu.frame
        while frame == self.ppu.frame
        {
            cpuCycles += self.step()
        }
        return cpuCycles
    }
    
    func stepSeconds(seconds aSeconds: Float64)
    {
        var cycles = Int(Float64(CPU.frequency) * aSeconds)
        while cycles > 0
        {
            cycles -= self.step()
        }
    }
}
