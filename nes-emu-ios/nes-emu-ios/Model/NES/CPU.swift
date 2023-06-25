//
//  CPU.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/4/20.
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
import os

/// Contains information that the CPU instruction functions use
struct StepInfo
{
    /// memory address
    let address: UInt16
    
    /// program counter
    let pc: UInt16
    
    /// addressing mode
    let mode: AddressingMode
}

struct InstructionInfo
{
    /// the 6502 CPU function to call
    let instruction: (_ cpu: inout CPU, _ stepInfo: StepInfo) -> ()
    
    /// the addressing mode of the instruction
    let mode: AddressingMode
    
    /// the number of cycles used by each instruction, not including conditional cycles
    let cycles: UInt8
    
    /// number of cycles the instruction takes if a page boundary is crossed
    let pageBoundaryCycles: UInt8
    
    /// the size of the instruction in bytes
    let bytes: UInt8
}

/// NES Central processing unit
struct CPU
{
    static let frequency: Int = 1789773
    var apu: APU
    var ppu: PPU
    var isHalted: Bool = false
    var controllers: [Controller]
    
    init(ppu aPPU: PPU, apu aAPU: APU, controllers aControllers: [Controller], state aState: CPUState? = nil)
    {
        self.apu = aAPU
        self.ppu = aPPU
        self.controllers = aControllers
        if let safeCPUState: CPUState = aState
        {
            self.ram = safeCPUState.ram
            self.a = safeCPUState.a
            self.x = safeCPUState.x
            self.y = safeCPUState.y
            self.pc = safeCPUState.pc
            self.sp = safeCPUState.sp
            self.cycles = safeCPUState.cycles
            self.stall = safeCPUState.stall
            self.set(flags: safeCPUState.flags)
        }
    }
    
    var cpuState: CPUState
    {
        return CPUState.init(ram: self.ram, a: self.a, x: self.x, y: self.y, pc: self.pc, sp: self.sp, cycles: self.cycles, flags: self.flags(), interrupt: self.interrupt.rawValue, stall: self.stall)
    }
    
    /// 2KB RAM
    private var ram: [UInt8] = [UInt8].init(repeating: 0, count: 2048)
    
    /// all 6502 op codes, containing all combinations of instructions and their associated addressing mode(s).  some op codes point to "illegal" instructions (such as slo, kil, anc, rla, sre, alr, rra, arr, sax, xaa, ahx, tas, shy, shx, lax, las, dcp, axs, isc) which won't do anything
    private static let instructionTable: [InstructionInfo] = [
        InstructionInfo(instruction: CPU.brk, mode: .implied,          cycles: 7, pageBoundaryCycles: 0, bytes: 2), // 00
        InstructionInfo(instruction: CPU.ora, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 01
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // 02
        InstructionInfo(instruction: CPU.slo, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // 03
        InstructionInfo(instruction: CPU.nop, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 04
        InstructionInfo(instruction: CPU.ora, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 05
        InstructionInfo(instruction: CPU.asl, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // 06
        InstructionInfo(instruction: CPU.slo, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // 07
        InstructionInfo(instruction: CPU.php, mode: .implied,          cycles: 3, pageBoundaryCycles: 0, bytes: 1), // 08
        InstructionInfo(instruction: CPU.ora, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 09
        InstructionInfo(instruction: CPU.asl, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 0A
        InstructionInfo(instruction: CPU.anc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 0B
        InstructionInfo(instruction: CPU.nop, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // 0C
        InstructionInfo(instruction: CPU.ora, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // 0D
        InstructionInfo(instruction: CPU.asl, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // 0E
        InstructionInfo(instruction: CPU.slo, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // 0F
        InstructionInfo(instruction: CPU.bpl, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2), // 10
        InstructionInfo(instruction: CPU.ora, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2), // 11
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // 12
        InstructionInfo(instruction: CPU.slo, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // 13
        InstructionInfo(instruction: CPU.nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 14
        InstructionInfo(instruction: CPU.ora, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 15
        InstructionInfo(instruction: CPU.asl, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 16
        InstructionInfo(instruction: CPU.slo, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 17
        InstructionInfo(instruction: CPU.clc, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 18
        InstructionInfo(instruction: CPU.ora, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 19
        InstructionInfo(instruction: CPU.nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 1A
        InstructionInfo(instruction: CPU.slo, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 1B
        InstructionInfo(instruction: CPU.nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 1C
        InstructionInfo(instruction: CPU.ora, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 1D
        InstructionInfo(instruction: CPU.asl, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 1E
        InstructionInfo(instruction: CPU.slo, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 1F
        InstructionInfo(instruction: CPU.jsr, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // 20
        InstructionInfo(instruction: CPU.and, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 21
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // 22
        InstructionInfo(instruction: CPU.rla, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // 23
        InstructionInfo(instruction: CPU.bit, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 24
        InstructionInfo(instruction: CPU.and, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 25
        InstructionInfo(instruction: CPU.rol, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // 26
        InstructionInfo(instruction: CPU.rla, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // 27
        InstructionInfo(instruction: CPU.plp, mode: .implied,          cycles: 4, pageBoundaryCycles: 0, bytes: 1), // 28
        InstructionInfo(instruction: CPU.and, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 29
        InstructionInfo(instruction: CPU.rol, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 2A
        InstructionInfo(instruction: CPU.anc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 2B
        InstructionInfo(instruction: CPU.bit, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // 2C
        InstructionInfo(instruction: CPU.and, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // 2D
        InstructionInfo(instruction: CPU.rol, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // 2E
        InstructionInfo(instruction: CPU.rla, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // 2F
        InstructionInfo(instruction: CPU.bmi, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2), // 30
        InstructionInfo(instruction: CPU.and, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2), // 31
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // 32
        InstructionInfo(instruction: CPU.rla, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // 33
        InstructionInfo(instruction: CPU.nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 34
        InstructionInfo(instruction: CPU.and, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 35
        InstructionInfo(instruction: CPU.rol, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 36
        InstructionInfo(instruction: CPU.rla, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 37
        InstructionInfo(instruction: CPU.sec, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 38
        InstructionInfo(instruction: CPU.and, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 39
        InstructionInfo(instruction: CPU.nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 3A
        InstructionInfo(instruction: CPU.rla, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 3B
        InstructionInfo(instruction: CPU.nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 3C
        InstructionInfo(instruction: CPU.and, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 3D
        InstructionInfo(instruction: CPU.rol, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 3E
        InstructionInfo(instruction: CPU.rla, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 3F
        InstructionInfo(instruction: CPU.rti, mode: .implied,          cycles: 6, pageBoundaryCycles: 0, bytes: 1), // 40
        InstructionInfo(instruction: CPU.eor, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 41
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // 42
        InstructionInfo(instruction: CPU.sre, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // 43
        InstructionInfo(instruction: CPU.nop, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 44
        InstructionInfo(instruction: CPU.eor, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 45
        InstructionInfo(instruction: CPU.lsr, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // 46
        InstructionInfo(instruction: CPU.sre, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // 47
        InstructionInfo(instruction: CPU.pha, mode: .implied,          cycles: 3, pageBoundaryCycles: 0, bytes: 1), // 48
        InstructionInfo(instruction: CPU.eor, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 49
        InstructionInfo(instruction: CPU.lsr, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 4A
        InstructionInfo(instruction: CPU.alr, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 4B
        InstructionInfo(instruction: CPU.jmp, mode: .absolute,         cycles: 3, pageBoundaryCycles: 0, bytes: 3), // 4C
        InstructionInfo(instruction: CPU.eor, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // 4D
        InstructionInfo(instruction: CPU.lsr, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // 4E
        InstructionInfo(instruction: CPU.sre, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // 4F
        InstructionInfo(instruction: CPU.bvc, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2), // 50
        InstructionInfo(instruction: CPU.eor, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2), // 51
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // 52
        InstructionInfo(instruction: CPU.sre, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // 53
        InstructionInfo(instruction: CPU.nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 54
        InstructionInfo(instruction: CPU.eor, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 55
        InstructionInfo(instruction: CPU.lsr, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 56
        InstructionInfo(instruction: CPU.sre, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 57
        InstructionInfo(instruction: CPU.cli, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 58
        InstructionInfo(instruction: CPU.eor, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 59
        InstructionInfo(instruction: CPU.nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 5A
        InstructionInfo(instruction: CPU.sre, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 5B
        InstructionInfo(instruction: CPU.nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 5C
        InstructionInfo(instruction: CPU.eor, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 5D
        InstructionInfo(instruction: CPU.lsr, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 5E
        InstructionInfo(instruction: CPU.sre, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 5F
        InstructionInfo(instruction: CPU.rts, mode: .implied,          cycles: 6, pageBoundaryCycles: 0, bytes: 1), // 60
        InstructionInfo(instruction: CPU.adc, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 61
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // 62
        InstructionInfo(instruction: CPU.rra, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // 63
        InstructionInfo(instruction: CPU.nop, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 64
        InstructionInfo(instruction: CPU.adc, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 65
        InstructionInfo(instruction: CPU.ror, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // 66
        InstructionInfo(instruction: CPU.rra, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // 67
        InstructionInfo(instruction: CPU.pla, mode: .implied,          cycles: 4, pageBoundaryCycles: 0, bytes: 1), // 68
        InstructionInfo(instruction: CPU.adc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 69
        InstructionInfo(instruction: CPU.ror, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 6A
        InstructionInfo(instruction: CPU.arr, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 6B
        InstructionInfo(instruction: CPU.jmp, mode: .indirect,         cycles: 5, pageBoundaryCycles: 0, bytes: 3), // 6C
        InstructionInfo(instruction: CPU.adc, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // 6D
        InstructionInfo(instruction: CPU.ror, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // 6E
        InstructionInfo(instruction: CPU.rra, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // 6F
        InstructionInfo(instruction: CPU.bvs, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2), // 70
        InstructionInfo(instruction: CPU.adc, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2), // 71
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // 72
        InstructionInfo(instruction: CPU.rra, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // 73
        InstructionInfo(instruction: CPU.nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 74
        InstructionInfo(instruction: CPU.adc, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 75
        InstructionInfo(instruction: CPU.ror, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 76
        InstructionInfo(instruction: CPU.rra, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 77
        InstructionInfo(instruction: CPU.sei, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 78
        InstructionInfo(instruction: CPU.adc, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 79
        InstructionInfo(instruction: CPU.nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 7A
        InstructionInfo(instruction: CPU.rra, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 7B
        InstructionInfo(instruction: CPU.nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 7C
        InstructionInfo(instruction: CPU.adc, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // 7D
        InstructionInfo(instruction: CPU.ror, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 7E
        InstructionInfo(instruction: CPU.rra, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // 7F
        InstructionInfo(instruction: CPU.nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 80
        InstructionInfo(instruction: CPU.sta, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 81
        InstructionInfo(instruction: CPU.nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 82
        InstructionInfo(instruction: CPU.sax, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 83
        InstructionInfo(instruction: CPU.sty, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 84
        InstructionInfo(instruction: CPU.sta, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 85
        InstructionInfo(instruction: CPU.stx, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 86
        InstructionInfo(instruction: CPU.sax, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // 87
        InstructionInfo(instruction: CPU.dey, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 88
        InstructionInfo(instruction: CPU.nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 89
        InstructionInfo(instruction: CPU.txa, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 8A
        InstructionInfo(instruction: CPU.xaa, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // 8B
        InstructionInfo(instruction: CPU.sty, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // 8C
        InstructionInfo(instruction: CPU.sta, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // 8D
        InstructionInfo(instruction: CPU.stx, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // 8E
        InstructionInfo(instruction: CPU.sax, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // 8F
        InstructionInfo(instruction: CPU.bcc, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2), // 90
        InstructionInfo(instruction: CPU.sta, mode: .indirectYIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 91
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // 92
        InstructionInfo(instruction: CPU.ahx, mode: .indirectYIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // 93
        InstructionInfo(instruction: CPU.sty, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 94
        InstructionInfo(instruction: CPU.sta, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 95
        InstructionInfo(instruction: CPU.stx, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 96
        InstructionInfo(instruction: CPU.sax, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // 97
        InstructionInfo(instruction: CPU.tya, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 98
        InstructionInfo(instruction: CPU.sta, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 3), // 99
        InstructionInfo(instruction: CPU.txs, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // 9A
        InstructionInfo(instruction: CPU.tas, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 3), // 9B
        InstructionInfo(instruction: CPU.shy, mode: .absoluteXIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 3), // 9C
        InstructionInfo(instruction: CPU.sta, mode: .absoluteXIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 3), // 9D
        InstructionInfo(instruction: CPU.shx, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 3), // 9E
        InstructionInfo(instruction: CPU.ahx, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 3), // 9F
        InstructionInfo(instruction: CPU.ldy, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // A0
        InstructionInfo(instruction: CPU.lda, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // A1
        InstructionInfo(instruction: CPU.ldx, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // A2
        InstructionInfo(instruction: CPU.lax, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // A3
        InstructionInfo(instruction: CPU.ldy, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // A4
        InstructionInfo(instruction: CPU.lda, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // A5
        InstructionInfo(instruction: CPU.ldx, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // A6
        InstructionInfo(instruction: CPU.lax, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // A7
        InstructionInfo(instruction: CPU.tay, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // A8
        InstructionInfo(instruction: CPU.lda, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // A9
        InstructionInfo(instruction: CPU.tax, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // AA
        InstructionInfo(instruction: CPU.lax, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // AB
        InstructionInfo(instruction: CPU.ldy, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // AC
        InstructionInfo(instruction: CPU.lda, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // AD
        InstructionInfo(instruction: CPU.ldx, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // AE
        InstructionInfo(instruction: CPU.lax, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // AF
        InstructionInfo(instruction: CPU.bcs, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2), // B0
        InstructionInfo(instruction: CPU.lda, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2), // B1
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // B2
        InstructionInfo(instruction: CPU.lax, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2), // B3
        InstructionInfo(instruction: CPU.ldy, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // B4
        InstructionInfo(instruction: CPU.lda, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // B5
        InstructionInfo(instruction: CPU.ldx, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // B6
        InstructionInfo(instruction: CPU.lax, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // B7
        InstructionInfo(instruction: CPU.clv, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // B8
        InstructionInfo(instruction: CPU.lda, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // B9
        InstructionInfo(instruction: CPU.tsx, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // BA
        InstructionInfo(instruction: CPU.las, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // BB
        InstructionInfo(instruction: CPU.ldy, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // BC
        InstructionInfo(instruction: CPU.lda, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // BD
        InstructionInfo(instruction: CPU.ldx, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // BE
        InstructionInfo(instruction: CPU.lax, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // BF
        InstructionInfo(instruction: CPU.cpy, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // C0
        InstructionInfo(instruction: CPU.cmp, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // C1
        InstructionInfo(instruction: CPU.nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // C2
        InstructionInfo(instruction: CPU.dcp, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // C3
        InstructionInfo(instruction: CPU.cpy, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // C4
        InstructionInfo(instruction: CPU.cmp, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // C5
        InstructionInfo(instruction: CPU.dec, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // C6
        InstructionInfo(instruction: CPU.dcp, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // C7
        InstructionInfo(instruction: CPU.iny, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // C8
        InstructionInfo(instruction: CPU.cmp, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // C9
        InstructionInfo(instruction: CPU.dex, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // CA
        InstructionInfo(instruction: CPU.sbx, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // CB
        InstructionInfo(instruction: CPU.cpy, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // CC
        InstructionInfo(instruction: CPU.cmp, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // CD
        InstructionInfo(instruction: CPU.dec, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // CE
        InstructionInfo(instruction: CPU.dcp, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // CF
        InstructionInfo(instruction: CPU.bne, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2), // D0
        InstructionInfo(instruction: CPU.cmp, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2), // D1
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // D2
        InstructionInfo(instruction: CPU.dcp, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // D3
        InstructionInfo(instruction: CPU.nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // D4
        InstructionInfo(instruction: CPU.cmp, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // D5
        InstructionInfo(instruction: CPU.dec, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // D6
        InstructionInfo(instruction: CPU.dcp, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // D7
        InstructionInfo(instruction: CPU.cld, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // D8
        InstructionInfo(instruction: CPU.cmp, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // D9
        InstructionInfo(instruction: CPU.nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // DA
        InstructionInfo(instruction: CPU.dcp, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // DB
        InstructionInfo(instruction: CPU.nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // DC
        InstructionInfo(instruction: CPU.cmp, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // DD
        InstructionInfo(instruction: CPU.dec, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // DE
        InstructionInfo(instruction: CPU.dcp, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // DF
        InstructionInfo(instruction: CPU.cpx, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // E0
        InstructionInfo(instruction: CPU.sbc, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // E1
        InstructionInfo(instruction: CPU.nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // E2
        InstructionInfo(instruction: CPU.isc, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // E3
        InstructionInfo(instruction: CPU.cpx, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // E4
        InstructionInfo(instruction: CPU.sbc, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2), // E5
        InstructionInfo(instruction: CPU.inc, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // E6
        InstructionInfo(instruction: CPU.isc, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2), // E7
        InstructionInfo(instruction: CPU.inx, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // E8
        InstructionInfo(instruction: CPU.sbc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // E9
        InstructionInfo(instruction: CPU.nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // EA
        InstructionInfo(instruction: CPU.sbc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2), // EB
        InstructionInfo(instruction: CPU.cpx, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // EC
        InstructionInfo(instruction: CPU.sbc, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3), // ED
        InstructionInfo(instruction: CPU.inc, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // EE
        InstructionInfo(instruction: CPU.isc, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3), // EF
        InstructionInfo(instruction: CPU.beq, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2), // F0
        InstructionInfo(instruction: CPU.sbc, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2), // F1
        InstructionInfo(instruction: CPU.kil, mode: .implied,          cycles: 1, pageBoundaryCycles: 0, bytes: 1), // F2
        InstructionInfo(instruction: CPU.isc, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 2), // F3
        InstructionInfo(instruction: CPU.nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // F4
        InstructionInfo(instruction: CPU.sbc, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2), // F5
        InstructionInfo(instruction: CPU.inc, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // F6
        InstructionInfo(instruction: CPU.isc, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2), // F7
        InstructionInfo(instruction: CPU.sed, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // F8
        InstructionInfo(instruction: CPU.sbc, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // F9
        InstructionInfo(instruction: CPU.nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1), // FA
        InstructionInfo(instruction: CPU.isc, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // FB
        InstructionInfo(instruction: CPU.nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // FC
        InstructionInfo(instruction: CPU.sbc, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3), // FD
        InstructionInfo(instruction: CPU.inc, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // FE
        InstructionInfo(instruction: CPU.isc, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3), // FF
    ]

    /// number of cycles
    private(set) var cycles: UInt64 = 0
    
    /// program counter
    private var pc: UInt16 = 0
    
    /// stack pointer
    private var sp: UInt8 = 0
    
    /// a register
    private var a: UInt8 = 0
    
    /// x register
    private var x: UInt8 = 0
    
    /// y register
    private var y: UInt8 = 0
    
    /// carry flag
    private var c: Bool = false
    
    /// zero flag
    private var z: Bool = false
    
    /// interrupt disable flag
    private var i: Bool = false
    
    /// decimal mode flag
    private var d: Bool = false
    
    /// break command flag
    private var b: Bool = false
    
    /// unused flag
    private var u: Bool = false
    
    /// overflow flag
    private var v: Bool = false
    
    /// negative flag
    private var n: Bool = false
    
    /// interrupt type to perform
    private var interrupt: Interrupt = .none
    
    /// number of cycles to stall
    private var stall: UInt64 = 0
    
    // MARK: Reset
    
    /// Reset resets the CPU to its initial powerup state
    mutating func reset()
    {
        self.pc = self.read16(address: 0xFFFC)
        self.sp = 0xFD
        self.set(flags: 0x24)
        
        self.ppu.reset()
    }
    
    // MARK: Flag Operations
    
    /// returns a UInt8 with flag bits arranged as c,z,i,d,b,u,v,n
    private func flags() -> UInt8
    {
        let flagByte: UInt8 = UInt8.init(fromLittleEndianBitArray: [self.c, self.z, self.i, self.d, self.b, self.u, self.v, self.n])
        return flagByte
    }
    
    /// sets cpu flags from a UInt8 with bits arranged as c,z,i,d,b,u,v,n
    private mutating func set(flags aFlags: UInt8)
    {
        let flagBits = aFlags.littleEndianBitArray
        self.c = flagBits[0]
        self.z = flagBits[1]
        self.i = flagBits[2]
        self.d = flagBits[3]
        self.b = flagBits[4]
        self.u = flagBits[5]
        self.v = flagBits[6]
        self.n = flagBits[7]
    }
    
    /// sets the zero flag if the argument is zero
    private mutating func setZ(value aValue: UInt8)
    {
        self.z = (aValue == 0) ? true : false
    }
    
    /// sets the negative flag if the argument is negative (high bit is set)
    private mutating func setN(value aValue: UInt8)
    {
        self.n = (aValue & 0x80 != 0) ? true : false
    }

    ///  sets the zero flag and the negative flag
    private mutating func setZN(value aValue: UInt8)
    {
        self.setZ(value: aValue)
        self.setN(value: aValue)
    }
    
    /// compare two values and set zero, negative, and carry flags accordingly
    private mutating func compare(valueA aValueA: UInt8, valueB aValueB: UInt8)
    {
        self.setZN(value: aValueA &- aValueB)
        self.c = aValueA >= aValueB ? true : false
    }
    
    // MARK: Memory
    
    mutating func read(address aAddress: UInt16) -> UInt8
    {
        switch aAddress {
        case 0x0000 ..< 0x2000:
            return self.ram[Int(aAddress % 0x0800)]
        case 0x2000 ..< 0x4000:
            return self.ppu.readRegister(address: 0x2000 + (aAddress % 8))
        case 0x4014:
            return self.ppu.readRegister(address: aAddress)
        case 0x4015:
            return self.apu.readRegister(address: aAddress)
        case 0x4016:
            return self.controllers[0].read()
        case 0x4017:
            return self.controllers[1].read()
        case 0x4000 ..< 0x5000:
            return 0
            // TODO: I/O registers
        case 0x5000 ... 0xFFFF:
            return self.ppu.mapper.cpuRead(address: aAddress)
        default:
            return 0
        }
    }
    
    mutating func write(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress {
        case 0x0000 ..< 0x2000:
            self.ram[Int(aAddress % 0x0800)] = aValue
        case 0x2000 ..< 0x4000:
            self.ppu.writeRegister(address: 0x2000 + (aAddress % 8), value: aValue)
        case 0x4000 ..< 0x4014:
            self.apu.writeRegister(address: aAddress, value: aValue)
        case 0x4014:
            let startIndex: Int = Int(UInt16(aValue) << 8)
            self.ppu.writeOAMDMA(oamDMA: [UInt8](self.ram[startIndex ..< startIndex + 256]))
            self.stall += (self.cycles % 2 == 0) ? 513 : 514
        case 0x4015:
            self.apu.writeRegister(address: aAddress, value: aValue)
        case 0x4016:
            self.controllers[0].write(value: aValue)
            self.controllers[1].write(value: aValue)
        case 0x4017:
            self.apu.writeRegister(address: aAddress, value: aValue)
        case 0x4000 ..< 0x5000:
            // TODO: I/O registers
            break
        case 0x5000 ... 0xFFFF:
            self.ppu.mapper.cpuWrite(address: aAddress, value: aValue)
        default:
            break
        }
    }
    
    /// checks whether two 16-bit addresses reside on different pages
    private func pagesDiffer(address1 aAddress1: UInt16, address2 aAddress2: UInt16) -> Bool
    {
        return aAddress1 & 0xFF00 != aAddress2 & 0xFF00
    }
    
    /// reads two bytes using Read to return a double-word value
    private mutating func read16(address aAddress: UInt16) -> UInt16
    {
        let lo: UInt16 = UInt16(self.read(address: aAddress))
        let hi: UInt16 = UInt16(self.read(address: aAddress &+ 1))
        return (hi << 8) | lo
    }

    /// emulates a 6502 bug that caused the low byte to wrap without incrementing the high byte
    private mutating func read16bug(address aAddress: UInt16) -> UInt16
    {
        let a: UInt16 = aAddress
        let b: UInt16 = (a & 0xFF00) | UInt16((a % 256) &+ 1)
        let lo = self.read(address: a)
        let hi = self.read(address: b)
        return (UInt16(hi) << 8) | UInt16(lo)
    }
    
    // MARK: Stack
    
    /// pushes a byte onto the stack
    private mutating func push(value aValue: UInt8)
    {
        self.write(address: 0x100 | UInt16(self.sp), value: aValue)
        self.sp &-= 1
    }

    /// pops a byte from the stack
    private mutating func pull() -> UInt8
    {
        self.sp &+= 1
        return self.read(address: 0x100 | UInt16(self.sp))
    }

    /// pushes two bytes onto the stack
    private mutating func push16(value aValue: UInt16)
    {
        let hi: UInt8 = UInt8(aValue >> 8)
        let lo: UInt8 = UInt8(aValue & 0xFF)
        self.push(value: hi)
        self.push(value: lo)
    }

    // pull16 pops two bytes from the stack
    private mutating func pull16() -> UInt16
    {
        let lo: UInt16 = UInt16(self.pull())
        let hi: UInt16 = UInt16(self.pull())
        return (hi << 8) | lo
    }
    
    // MARK: Interrupt Operations
    
    /// causes a non-maskable interrupt to occur on the next cycle
    mutating func triggerNMI()
    {
        self.interrupt = .nmi
    }

    /// causes an IRQ interrupt to occur on the next cycle, if the interrupt disable flag is not set
    mutating func triggerIRQ()
    {
        if self.i == false
        {
            self.interrupt = .irq
        }
    }
    
    // MARK: Timing
    
    /// adds a cycle for taking a branch and adds another cycle if the branch jumps to a new page
    private mutating func addBranchCycles(stepInfo aStepInfo: StepInfo)
    {
        self.cycles &+= 1
        if self.pagesDiffer(address1: aStepInfo.pc, address2: aStepInfo.address)
        {
            self.cycles &+= 1
        }
    }
    
    /// NMI - Non-Maskable Interrupt
    private mutating func nmi()
    {
        self.push16(value: self.pc)
        CPU.php(cpu: &self, stepInfo: StepInfo(address: 0, pc: 0, mode: .implied))
        self.pc = self.read16(address: 0xFFFA)
        self.i = true
        self.cycles &+= 7
    }

    /// IRQ - IRQ Interrupt
    private mutating func irq()
    {
        self.push16(value: self.pc)
        CPU.php(cpu: &self, stepInfo: StepInfo(address: 0, pc: 0, mode: .implied)) // placeholder StepInfo value (unused)
        self.pc = self.read16(address: 0xFFFE)
        self.i = true
        self.cycles &+= 7
    }
    
    /// executes a single CPU instruction, and returns the number of CPU cycles used
    mutating func step() -> Int
    {
        let numCPUCyclesThisStep: Int
        
        guard self.stall == 0
            else
        {
            numCPUCyclesThisStep = 1
            self.stall -= 1
            self.stepOthers(forNumCPUCycles: numCPUCyclesThisStep)
            return numCPUCyclesThisStep
        }

        let oldCycles = self.cycles

        switch self.interrupt
        {
        case .nmi:
            self.nmi()
        case .irq:
            self.irq()
            self.isHalted = false
        default: break
        }
        self.interrupt = .none

        let opcode = self.read(address: self.pc)
        let instructioninfo: InstructionInfo = CPU.instructionTable[Int(opcode)]
        let mode: AddressingMode = instructioninfo.mode
        let address: UInt16
        let pageCrossed: Bool
        switch mode
        {
        case .absolute:
            address = self.read16(address: self.pc &+ 1)
            pageCrossed = false
        case .absoluteXIndexed:
            address = self.read16(address: self.pc &+ 1) &+ UInt16(self.x)
            pageCrossed = self.pagesDiffer(address1: address &- UInt16(self.x), address2: address)
        case .absoluteYIndexed:
            address = self.read16(address: self.pc &+ 1) &+ UInt16(self.y)
            pageCrossed = self.pagesDiffer(address1: address &- UInt16(self.y), address2: address)
        case .accumulator:
            address = 0
            pageCrossed = false
        case .immediate:
            address = self.pc &+ 1
            pageCrossed = false
        case .implied:
            address = 0
            pageCrossed = false
        case .xIndexedIndirect:
            let zero: UInt8 = self.read(address: self.pc &+ 1) &+ self.x
                        
            if zero == 0xFF
            {
                address = UInt16(self.read(address: 0x00FF)) | (UInt16(self.read(address: 0x0000)) << 8)
            }
            else
            {
                address = self.read16bug(address: UInt16(zero))
            }

            pageCrossed = false
        case .indirect:
            /*
             http://6502.org/tutorials/6502opcodes.html
             JMP (Indirect) must never use a vector beginning on the last byte of a page (e.g. JMP ($30FF)).
             For example, if address $3000 contains $40, $30FF contains $80, and $3100 contains $50, the result of JMP ($30FF) will be a transfer of control to $4080 rather than $5080 as you intended i.e. the 6502 took the low byte of the address from $30FF and the high byte from $3000.
             */
            let vector = self.read16(address: self.pc &+ 1)
            if vector & 0x00FF == 0x00FF
            {
                let lo = self.read(address: vector)
                let hi = self.read(address: vector &- 0x00FF)
                address = UInt16(lo) | (UInt16(hi) << 8)
            }
            else
            {
                address = self.read16bug(address: vector)
            }
            pageCrossed = false
        case .indirectYIndexed:
            let zero: UInt8 = self.read(address: self.pc &+ 1)
                        
            if zero == 0xFF
            {
                address = UInt16(self.read(address: 0x00FF)) | (UInt16(self.read(address: 0x0000)) << 8) &+ UInt16(self.y)
            }
            else
            {
                address = self.read16bug(address: UInt16(zero)) &+ UInt16(self.y)
            }

            pageCrossed = self.pagesDiffer(address1: address &- UInt16(self.y), address2: address)
        case .relative:
            let offset = UInt16(self.read(address: self.pc &+ 1))
            if offset < 0x80 {
                address = self.pc &+ 2 &+ offset
            } else {
                address = self.pc &+ 2 &+ offset &- 0x100
            }
            pageCrossed = false
        case .zeropage:
            address = UInt16(self.read(address: self.pc &+ 1))
            pageCrossed = false
        case .zeroPageXIndexed:
            address = UInt16(self.read(address: self.pc &+ 1) &+ self.x) & 0xff
            pageCrossed = false
        case .zeroPageYIndexed:
            address = UInt16(self.read(address: self.pc &+ 1) &+ self.y) & 0xff
            pageCrossed = false
        }

        self.pc &+= UInt16(instructioninfo.bytes)
        self.cycles &+= UInt64(instructioninfo.cycles)
        if pageCrossed
        {
            self.cycles &+= UInt64(instructioninfo.pageBoundaryCycles)
        }
        let info: StepInfo = StepInfo(address: address, pc: self.pc, mode: mode)
        instructioninfo.instruction(&self, info)
        
        numCPUCyclesThisStep = Int(self.cycles - oldCycles)
        
        self.stepOthers(forNumCPUCycles: numCPUCyclesThisStep)
        
        return numCPUCyclesThisStep
    }
    
    private mutating func stepOthers(forNumCPUCycles aNumCPUCycles: Int)
    {
        // PPU Step
        for _ in 0 ..< aNumCPUCycles * 3
        {
            let ppuStepResults: PPUStepResults = self.ppu.step()
            if let safeRequestedInterrupt: Interrupt = ppuStepResults.requestedCPUInterrupt
            {
                switch safeRequestedInterrupt
                {
                case .irq: self.triggerIRQ()
                case .nmi: self.triggerNMI()
                case .none: self.interrupt = .none
                }
            }
        }
        
        // APU Step
        for _ in 0 ..< aNumCPUCycles
        {
            let dmcCurrentAddressValue: UInt8 = self.read(address: self.apu.dmcCurrentAddress)
            let apuStepResults: APUStepResults = self.apu.step(dmcCurrentAddressValue: dmcCurrentAddressValue)
            self.stall += apuStepResults.numCPUStallCycles
            if apuStepResults.shouldTriggerIRQOnCPU
            {
                self.triggerIRQ()
            }
        }
    }
    
    // MARK: 6502 functions
    
    /// ADC - Add with Carry
    private static func adc(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        let a: UInt8 = aCPU.a
        let b: UInt8 = aCPU.read(address: aStepInfo.address)
        let c: UInt8 = aCPU.c ? 1 : 0
        aCPU.a = a &+ b &+ c
        aCPU.setZN(value: aCPU.a)
        aCPU.c = Int(a) + Int(b) + Int(c) > 0xFF
        aCPU.v = ((a ^ b) & 0x80) == 0 && ((a ^ aCPU.a) & 0x80) != 0
    }

    /// AND - Logical AND
    private static func and(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.a = aCPU.a & aCPU.read(address: aStepInfo.address)
        aCPU.setZN(value: aCPU.a)
    }

    /// ASL - Arithmetic Shift Left
    private static func asl(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aStepInfo.mode == .accumulator
        {
            aCPU.c = ((aCPU.a >> 7) & 1) == 1
            aCPU.a <<= 1
            aCPU.setZN(value: aCPU.a)
        }
        else
        {
            var value = aCPU.read(address: aStepInfo.address)
            aCPU.c = ((value >> 7) & 1) == 1
            value <<= 1
            aCPU.write(address: aStepInfo.address, value: value)
            aCPU.setZN(value: value)
        }
    }

    /// BCC - Branch if Carry Clear
    private static func bcc(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aCPU.c == false
        {
            aCPU.pc = aStepInfo.address
            aCPU.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BCS - Branch if Carry Set
    private static func bcs(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aCPU.c == true
        {
            aCPU.pc = aStepInfo.address
            aCPU.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BEQ - Branch if Equal
    private static func beq(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aCPU.z == true
        {
            aCPU.pc = aStepInfo.address
            aCPU.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BIT - Bit Test
    private static func bit(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        let value = aCPU.read(address: aStepInfo.address)
        aCPU.v = ((value >> 6) & 1) == 1
        aCPU.setZ(value: value & aCPU.a)
        aCPU.setN(value: value)
    }

    /// BMI - Branch if Minus
    private static func bmi(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aCPU.n == true
        {
            aCPU.pc = aStepInfo.address
            aCPU.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BNE - Branch if Not Equal
    private static func bne(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aCPU.z == false
        {
            aCPU.pc = aStepInfo.address
            aCPU.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BPL - Branch if Positive
    private static func bpl(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aCPU.n == false
        {
            aCPU.pc = aStepInfo.address
            aCPU.addBranchCycles(stepInfo: aStepInfo)
        }
    }
    
    /// BRK - Force Interrupt
    private static func brk(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.push16(value: aCPU.pc)
        CPU.php(cpu: &aCPU, stepInfo: aStepInfo)
        CPU.sei(cpu: &aCPU, stepInfo: aStepInfo)
        aCPU.pc = aCPU.read16(address: 0xFFFE)
    }
    
    /// BVC - Branch if Overflow Clear
    private static func bvc(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aCPU.v == false
        {
            aCPU.pc = aStepInfo.address
            aCPU.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BVS - Branch if Overflow Set
    private static func bvs(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aCPU.v == true
        {
            aCPU.pc = aStepInfo.address
            aCPU.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// CLC - Clear Carry Flag
    private static func clc(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.c = false
    }

    /// CLD - Clear Decimal Mode
    private static func cld(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.d = false
    }

    /// CLI - Clear Interrupt Disable
    private static func cli(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.i = false
    }

    /// CLV - Clear Overflow Flag
    private static func clv(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.v = false
    }

    /// CMP - Compare
    private static func cmp(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        let value = aCPU.read(address: aStepInfo.address)
        aCPU.compare(valueA: aCPU.a, valueB: value)
    }

    /// CPX - Compare X Register
    private static func cpx(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        let value = aCPU.read(address: aStepInfo.address)
        aCPU.compare(valueA: aCPU.x, valueB: value)
    }

    /// CPY - Compare Y Register
    private static func cpy(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        let value = aCPU.read(address: aStepInfo.address)
        aCPU.compare(valueA: aCPU.y, valueB: value)
    }

    /// DEC - Decrement Memory
    private static func dec(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        let value = aCPU.read(address: aStepInfo.address) &- 1
        aCPU.write(address: aStepInfo.address, value: value)
        aCPU.setZN(value: value)
    }

    /// DEX - Decrement X Register
    private static func dex(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.x &-= 1 // decrement and wrap if needed
        aCPU.setZN(value: aCPU.x)
    }

    /// DEY - Decrement Y Register
    private static func dey(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.y &-= 1 // decrement and wrap if needed
        aCPU.setZN(value: aCPU.y)
    }

    /// EOR - Exclusive OR
    private static func eor(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.a = aCPU.a ^ aCPU.read(address: aStepInfo.address)
        aCPU.setZN(value: aCPU.a)
    }

    /// INC - Increment Memory
    private static func inc(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        let value: UInt8 = aCPU.read(address: aStepInfo.address) &+ 1 // wrap if needed
        aCPU.write(address: aStepInfo.address, value: value)
        aCPU.setZN(value: value)
    }

    /// INX - Increment X Register
    private static func inx(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.x &+= 1 // increment and wrap if needed
        aCPU.setZN(value: aCPU.x)
    }

    /// INY - Increment Y Register
    private static func iny(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.y &+= 1 // increment and wrap if needed
        aCPU.setZN(value: aCPU.y)
    }

    /// JMP - Jump
    private static func jmp(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.pc = aStepInfo.address
    }

    /// JSR - Jump to Subroutine
    private static func jsr(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.push16(value: aCPU.pc - 1)
        aCPU.pc = aStepInfo.address
    }

    /// LDA - Load Accumulator
    private static func lda(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.a = aCPU.read(address: aStepInfo.address)
        aCPU.setZN(value: aCPU.a)
    }

    /// LDX - Load X Register
    private static func ldx(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.x = aCPU.read(address: aStepInfo.address)
        aCPU.setZN(value: aCPU.x)
    }

    /// LDY - Load Y Register
    private static func ldy(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.y = aCPU.read(address: aStepInfo.address)
        aCPU.setZN(value: aCPU.y)
    }

    /// LSR - Logical Shift Right
    private static func lsr(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aStepInfo.mode == .accumulator
        {
            aCPU.c = (aCPU.a & 1) == 1
            aCPU.a >>= 1
            aCPU.setZN(value: aCPU.a)
        }
        else
        {
            var value = aCPU.read(address: aStepInfo.address)
            aCPU.c = (value & 1) == 1
            value >>= 1
            aCPU.write(address: aStepInfo.address, value: value)
            aCPU.setZN(value: value)
        }
    }

    /// NOP - No Operation
    private static func nop(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        // do nothing
    }

    /// ORA - Logical Inclusive OR
    private static func ora(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.a = aCPU.a | aCPU.read(address: aStepInfo.address)
        aCPU.setZN(value: aCPU.a)
    }

    /// PHA - Push Accumulator
    private static func pha(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.push(value: aCPU.a)
    }

    /// PHP - Push Processor Status
    private static func php(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.push(value: aCPU.flags() | 0x10)
    }

    /// PLA - Pull Accumulator
    private static func pla(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.a = aCPU.pull()
        aCPU.setZN(value: aCPU.a)
    }

    /// PLP - Pull Processor Status
    private static func plp(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.set(flags: (aCPU.pull() & 0xEF) | 0x20)
    }

    /// ROL - Rotate Left
    private static func rol(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aStepInfo.mode == .accumulator
        {
            let c: UInt8 = aCPU.c ? 1 : 0
            aCPU.c = ((aCPU.a >> 7) & 1) == 1
            aCPU.a = (aCPU.a << 1) | c
            aCPU.setZN(value: aCPU.a)
        }
        else
        {
            let c: UInt8 = aCPU.c ? 1 : 0
            var value = aCPU.read(address: aStepInfo.address)
            aCPU.c = ((value >> 7) & 1) == 1
            value = (value << 1) | c
            aCPU.write(address: aStepInfo.address, value: value)
            aCPU.setZN(value: value)
        }
    }

    /// ROR - Rotate Right
    private static func ror(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        if aStepInfo.mode == .accumulator
        {
            let c: UInt8 = aCPU.c ? 1 : 0
            aCPU.c = (aCPU.a & 1) == 1
            aCPU.a = (aCPU.a >> 1) | (c << 7)
            aCPU.setZN(value: aCPU.a)
        }
        else
        {
            let c: UInt8 = aCPU.c ? 1 : 0
            var value = aCPU.read(address: aStepInfo.address)
            aCPU.c = (value & 1) == 1
            value = (value >> 1) | (c << 7)
            aCPU.write(address: aStepInfo.address, value: value)
            aCPU.setZN(value: value)
        }
    }

    /// RTI - Return from Interrupt
    private static func rti(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.set(flags: (aCPU.pull() & 0xEF) | 0x20)
        aCPU.pc = aCPU.pull16()
    }

    /// RTS - Return from Subroutine
    private static func rts(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.pc = aCPU.pull16() &+ 1
    }

    /// SBC - Subtract with Carry
    private static func sbc(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        let a: UInt8 = aCPU.a
        let b: UInt8 = aCPU.read(address: aStepInfo.address)
        let c: UInt8 = aCPU.c ? 1 : 0
        aCPU.a = a &- b &- (1 - c)
        aCPU.setZN(value: aCPU.a)
        aCPU.c = Int(a) - Int(b) - Int(1 - c) >= 0
        aCPU.v = ((a ^ b) & 0x80) != 0 && ((a ^ aCPU.a) & 0x80) != 0
    }

    /// SEC - Set Carry Flag
    private static func sec(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.c = true
    }

    /// SED - Set Decimal Flag
    private static func sed(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.d = true
    }

    /// SEI - Set Interrupt Disable
    private static func sei(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.i = true
    }

    /// STA - Store Accumulator
    private static func sta(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.write(address: aStepInfo.address, value: aCPU.a)
    }

    /// STX - Store X Register
    private static func stx(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.write(address: aStepInfo.address, value: aCPU.x)
    }

    /// STY - Store Y Register
    private static func sty(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.write(address: aStepInfo.address, value: aCPU.y)
    }

    /// TAX - Transfer Accumulator to X
    private static func tax(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.x = aCPU.a
        aCPU.setZN(value: aCPU.x)
    }

    /// TAY - Transfer Accumulator to Y
    private static func tay(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.y = aCPU.a
        aCPU.setZN(value: aCPU.y)
    }

    /// TSX - Transfer Stack Pointer to X
    private static func tsx(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.x = aCPU.sp
        aCPU.setZN(value: aCPU.x)
    }

    /// TXA - Transfer X to Accumulator
    private static func txa(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.a = aCPU.x
        aCPU.setZN(value: aCPU.a)
    }

    /// TXS - Transfer X to Stack Pointer
    private static func txs(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.sp = aCPU.x
    }

    /// TYA - Transfer Y to Accumulator
    private static func tya(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.a = aCPU.y
        aCPU.setZN(value: aCPU.a)
    }
    
    // MARK: Illegal Instructions

    private static func ahx(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         SHA (AHX, AXA)
         Stores A AND X AND (high-byte of addr. + 1) at addr.

         unstable: sometimes 'AND (H+1)' is dropped, page boundary crossings may not work (with the high-byte of the value used as the high-byte of the address)

         A AND X AND (H+1) -> M
         N    Z    C    I    D    V
         -    -    -    -    -    -
         addressing    assembler    opc    bytes    cycles
         absolut,Y    SHA oper,Y    9F     3        5      †
         (indirect),Y SHA (oper),Y  93     2        6      †
        */
        let value: UInt8 = aCPU.a & aCPU.x & aCPU.read(address: aStepInfo.address &+ 1)
        aCPU.write(address: aStepInfo.address, value: value)
    }
    
    private static func alr(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         ALR (ASR)
         AND oper + LSR

         A AND oper, 0 -> [76543210] -> C
         N    Z    C    I    D    V
         +    +    +    -    -    -
         addressing    assembler    opc    bytes    cycles
         immediate     ALR #oper    4B     2        2
        */
        aCPU.c = false
        aCPU.a = aCPU.a & aCPU.read(address: aStepInfo.address)
        if aCPU.a & 0x01 == 1
        {
            aCPU.c = true
        }
        aCPU.a >>= 1
        aCPU.setZN(value: aCPU.a)
    }
    
    private static func anc(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         ANC
         AND oper + set C as ASL

         A AND oper, bit(7) -> C
         N    Z    C    I    D    V
         +    +    +    -    -    -
         addressing    assembler    opc    bytes    cycles
         immediate    ANC #oper     0B     2        2
        */
        CPU.and(cpu: &aCPU, stepInfo: aStepInfo)
        aCPU.c = aCPU.a & 0x80 == 0x80
    }
    
    private static func arr(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
        ARR
        AND oper + ROR

        This operation involves the adder:
        V-flag is set according to (A AND oper) + oper
        The carry is not set, but bit 7 (sign) is exchanged with the carry

        A AND oper, C -> [76543210] -> C
        N    Z    C    I    D    V
        +    +    +    -    -    +
        addressing    assembler     opc    bytes    cycles
        immediate     ARR #oper     6B     2        2
        */
        let operandValue: UInt8 = aCPU.read(address: aStepInfo.address)
        aCPU.a = ((aCPU.a & operandValue) >> 1) | (aCPU.c ? 0x80 : 0x00)
        aCPU.c = aCPU.a & 0x40 != 0
        aCPU.v = ((aCPU.c ? 0x01 : 0x00) ^ ((aCPU.a >> 5) & 0x01)) != 0
        aCPU.setZN(value: aCPU.a)
    }
    
    private static func sbx(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         SBX (AXS, SAX)
         CMP and DEX at once, sets flags like CMP

         (A AND X) - oper -> X
         N    Z    C    I    D    V
         +    +    +    -    -    -
         addressing    assembler     opc    bytes    cycles
         immediate     SBX #oper     CB     2        2
        */
        let opValue: UInt8 = aCPU.read(address: aStepInfo.address)
        let value: UInt8 = (aCPU.a & aCPU.x) &- opValue
        aCPU.c = aCPU.a & aCPU.x >= opValue
        aCPU.x = value
        aCPU.setZN(value: value)
    }
    
    private static func dcp(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         DCP (DCM)
         DEC oper + CMP oper

         M - 1 -> M, A - M
         N    Z    C    I    D    V
         +    +    +    -    -    -
         addressing    assembler    opc    bytes    cycles
         zeropage    DCP oper    C7    2    5
         zeropage,X    DCP oper,X    D7    2    6
         absolute    DCP oper    CF    3    6
         absolut,X    DCP oper,X    DF    3    7
         absolut,Y    DCP oper,Y    DB    3    7
         (indirect,X)    DCP (oper,X)    C3    2    8
         (indirect),Y    DCP (oper),Y    D3    2    8
         */
        CPU.dec(cpu: &aCPU, stepInfo: aStepInfo)
        CPU.cmp(cpu: &aCPU, stepInfo: aStepInfo)
    }
    
    private static func isc(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         ISC (ISB, INS)
         INC oper + SBC oper

         M + 1 -> M, A - M - C -> A
         N    Z    C    I    D    V
         +    +    +    -    -    +
         addressing    assembler     opc    bytes    cycles
         zeropage      ISC oper      E7     2    5
         zeropage,X    ISC oper,X    F7     2    6
         absolute      ISC oper      EF     3    6
         absolut,X     ISC oper,X    FF     3    7
         absolut,Y     ISC oper,Y    FB     3    7
         (indirect,X)  ISC (oper,X)  E3     2    8
         (indirect),Y  ISC (oper),Y  F3     2    8
        */
        CPU.inc(cpu: &aCPU, stepInfo: aStepInfo)
        CPU.sbc(cpu: &aCPU, stepInfo: aStepInfo)
    }
    
    private static func kil(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        aCPU.isHalted = true
        aCPU.pc &-= 1
        aCPU.cycles &+= 0xFF
    }
    
    private static func las(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         LAS (LAR)
         LDA/TSX oper

         M AND SP -> A, X, SP
         N    Z    C    I    D    V
         +    +    -    -    -    -
         addressing    assembler    opc    bytes    cycles
         absolut,Y    LAS oper,Y    BB    3    4*
        */
        CPU.lda(cpu: &aCPU, stepInfo: aStepInfo)
        CPU.tsx(cpu: &aCPU, stepInfo: aStepInfo)
    }
    
    private static func lax(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         LAX
         LDA oper + LDX oper

         M -> A -> X
         N    Z    C    I    D    V
         +    +    -    -    -    -
         addressing    assembler     opc    bytes    cycles
         zeropage      LAX oper      A7     2        3
         zeropage,Y    LAX oper,Y    B7     2        4
         absolute      LAX oper      AF     3        4
         absolut,Y     LAX oper,Y    BF     3        4*
         (indirect,X)  LAX (oper,X)  A3     2        6
         (indirect),Y  LAX (oper),Y  B3     2        5*
        */
        CPU.lda(cpu: &aCPU, stepInfo: aStepInfo)
        CPU.ldx(cpu: &aCPU, stepInfo: aStepInfo)
    }
    
    private static func rla(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         RLA
         ROL oper + AND oper

         M = C <- [76543210] <- C, A AND M -> A
         N    Z    C    I    D    V
         +    +    +    -    -    -
         addressing    assembler    opc    bytes    cycles
         zeropage      RLA oper     27     2        5
         zeropage,X    RLA oper,X   37     2        6
         absolute      RLA oper     2F     3        6
         absolut,X     RLA oper,X   3F     3        7
         absolut,Y     RLA oper,Y   3B     3        7
         (indirect,X)  RLA (oper,X) 23     2        8
         (indirect),Y  RLA (oper),Y 33     2        8
        */
        CPU.rol(cpu: &aCPU, stepInfo: aStepInfo)
        CPU.and(cpu: &aCPU, stepInfo: aStepInfo)
    }
    
    private static func rra(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         RRA
         ROR oper + ADC oper

         M = C -> [76543210] -> C, A + M + C -> A, C
         N    Z    C    I    D    V
         +    +    +    -    -    +
         addressing    assembler     opc    bytes    cycles
         zeropage      RRA oper      67     2        5
         zeropage,X    RRA oper,X    77     2        6
         absolute      RRA oper      6F     3        6
         absolut,X     RRA oper,X    7F     3        7
         absolut,Y     RRA oper,Y    7B     3        7
         (indirect,X)  RRA (oper,X)  63     2        8
         (indirect),Y  RRA (oper),Y  73     2        8
        */
        CPU.ror(cpu: &aCPU, stepInfo: aStepInfo)
        CPU.adc(cpu: &aCPU, stepInfo: aStepInfo)
    }
    
    private static func sax(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         SAX (AXS, AAX)
         A and X are put on the bus at the same time (resulting effectively in an AND operation) and stored in M

         A AND X -> M
         N    Z    C    I    D    V
         -    -    -    -    -    -
         addressing    assembler     opc    bytes    cycles
         zeropage      SAX oper      87     2        3
         zeropage,Y    SAX oper,Y    97     2        4
         absolute      SAX oper      8F     3        4
         (indirect,X)  SAX (oper,X)  83     2        6
        */
        let value = aCPU.a & aCPU.x
        aCPU.write(address: aStepInfo.address, value: value)
    }
    
    private static func shx(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         SHX (A11, SXA, XAS)
         Stores X AND (high-byte of addr. + 1) at addr.

         unstable: sometimes 'AND (H+1)' is dropped, page boundary crossings may not work (with the high-byte of the value used as the high-byte of the address)

         X AND (H+1) -> M
         N    Z    C    I    D    V
         -    -    -    -    -    -
         addressing    assembler    opc    bytes    cycles
         absolut,Y    SHX oper,Y    9E    3    5      †
        */
        let newAddr = ((UInt16(aCPU.x) & ((aStepInfo.address >> 8) &+ 1)) << 8) | (aStepInfo.address & 0xFF)
        aCPU.write(address: newAddr, value: UInt8(newAddr >> 8))
    }
    
    private static func shy(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         SHY (A11, SYA, SAY)
         Stores Y AND (high-byte of addr. + 1) at addr.

         unstable: sometimes 'AND (H+1)' is dropped, page boundary crossings may not work (with the high-byte of the value used as the high-byte of the address)

         Y AND (H+1) -> M
         N    Z    C    I    D    V
         -    -    -    -    -    -
         addressing    assembler    opc    bytes    cycles
         absolut,X    SHY oper,X    9C    3    5      †
         */
        let newAddr = ((UInt16(aCPU.y) & ((aStepInfo.address >> 8) &+ 1)) << 8) | (aStepInfo.address & 0xFF)
        aCPU.write(address: newAddr, value: UInt8(newAddr >> 8))
    }
    
    private static func slo(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         SLO (ASO)
         ASL oper + ORA oper

         M = C <- [76543210] <- 0, A OR M -> A
         N    Z    C    I    D    V
         +    +    +    -    -    -
         addressing    assembler    opc    bytes    cycles
         zeropage      SLO oper      07    2        5
         zeropage,X    SLO oper,X    17    2        6
         absolute      SLO oper      0F    3        6
         absolut,X     SLO oper,X    1F    3        7
         absolut,Y     SLO oper,Y    1B    3        7
         (indirect,X)  SLO (oper,X)  03    2        8
         (indirect),Y  SLO (oper),Y  13    2        8
         */
        CPU.asl(cpu: &aCPU, stepInfo: aStepInfo)
        CPU.ora(cpu: &aCPU, stepInfo: aStepInfo)
    }
    
    private static func sre(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         SRE (LSE)
         LSR oper + EOR oper

         M = 0 -> [76543210] -> C, A EOR M -> A
         N    Z    C    I    D    V
         +    +    +    -    -    -
         addressing     assembler     opc    bytes    cycles
         zeropage       SRE oper      47     2        5
         zeropage,X     SRE oper,X    57     2        6
         absolute       SRE oper      4F     3        6
         absolut,X      SRE oper,X    5F     3        7
         absolut,Y      SRE oper,Y    5B     3        7
         (indirect,X)   SRE (oper,X)  43     2        8
         (indirect),Y   SRE (oper),Y  53     2        8
         */
        CPU.lsr(cpu: &aCPU, stepInfo: aStepInfo)
        CPU.eor(cpu: &aCPU, stepInfo: aStepInfo)
    }
    
    private static func tas(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         TAS (XAS, SHS)
         Puts A AND X in SP and stores A AND X AND (high-byte of addr. + 1) at addr.

         unstable: sometimes 'AND (H+1)' is dropped, page boundary crossings may not work (with the high-byte of the value used as the high-byte of the address)

         A AND X -> SP, A AND X AND (H+1) -> M
         N    Z    C    I    D    V
         -    -    -    -    -    -
         addressing    assembler    opc    bytes    cycles
         absolut,Y    TAS oper,Y    9B     3        5†
        */
        let value1: UInt8 = aCPU.a & aCPU.x
        let value2: UInt8 = value1 & aCPU.read(address: aStepInfo.address &+ 1)
        aCPU.sp = value1
        aCPU.write(address: aStepInfo.address, value: value2)
    }
    
    private static func xaa(cpu aCPU: inout CPU, stepInfo aStepInfo: StepInfo)
    {
        /*
         ANE (XAA)
         * AND X + AND oper

         Highly unstable, do not use.
         A base value in A is determined based on the contets of A and a constant, which may be typically $00, $ff, $ee, etc. The value of this constant depends on temerature, the chip series, and maybe other factors, as well.
         In order to eliminate these uncertaincies from the equation, use either 0 as the operand or a value of $FF in the accumulator.

         (A OR CONST) AND X AND oper -> A
         N    Z    C    I    D    V
         +    +    -    -    -    -
         addressing    assembler    opc    bytes    cycles
         immediate     ANE #oper     8B    2        2††
        */
        aCPU.a = aCPU.a & aCPU.x
        aCPU.setZN(value: aCPU.a)
    }
}

enum AddressingMode: UInt8
{
    case absolute, absoluteXIndexed, absoluteYIndexed, accumulator, immediate, implied, xIndexedIndirect, indirect, indirectYIndexed, relative, zeropage, zeroPageXIndexed, zeroPageYIndexed
}

enum Interrupt: UInt8
{
    case none, nmi, irq
}
