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
    /// the 6502 instruction
    let instruction: Instruction
    
    /// the addressing mode of the instruction
    let mode: AddressingMode
    
    /// the number of cycles used by each instruction, not including conditional cycles
    let cycles: UInt8
    
    /// number of cycles the instruction takes if a page boundary is crossed
    let pageBoundaryCycles: UInt8
    
    /// the size of the instruction in bytes
    let bytes: UInt8
    
    /// the underlying CPU function call
    let code: (_ stepInfo: StepInfo) -> Void
}

protocol CPUProtocol: MemoryProtocol
{
    func triggerIRQ()
    func triggerNMI()
    var stall: Int { get set }
    var cycles: UInt64 { get }
}

/// NES Central processing unit
class CPU: CPUProtocol
{
    static let frequency: Int = 1789773
    
    private weak var controller1: ControllerProtocol?
    private weak var controller2: ControllerProtocol?
    
    init(ppu aPPU: PPU, apu aAPU: APU, mapper aMapper: MapperProtocol?, controller1 aController1: ControllerProtocol?, controller2 aController2: ControllerProtocol?)
    {
        self.apu = aAPU
        self.ppu = aPPU
        self.mapper = aMapper
        self.controller1 = aController1
        self.controller2 = aController2
    }
    
    private weak var apu: APUProtocol?
    private weak var ppu: PPUProtocol?
    private weak var mapper: MapperProtocol?
    
    /// 2KB RAM
    private var ram: [UInt8] = [UInt8].init(repeating: 0, count: 2048)
    
    /// all 6502 op codes, containing all combinations of instructions and their associated addressing mode(s).  some op codes point to "illegal" instructions (such as slo, kil, anc, rla, sre, alr, rra, arr, sax, xaa, ahx, tas, shy, shx, lax, las, dcp, axs, isc) which won't do anything
    private lazy var instructionTable: [InstructionInfo] = {
        [
            InstructionInfo(instruction: .brk, mode: .implied,          cycles: 7, pageBoundaryCycles: 0, bytes: 2, code: { self.brk(stepInfo: $0) }),
            InstructionInfo(instruction: .ora, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .slo, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .ora, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(instruction: .asl, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.asl(stepInfo: $0) }),
            InstructionInfo(instruction: .slo, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(instruction: .php, mode: .implied,          cycles: 3, pageBoundaryCycles: 0, bytes: 1, code: { self.php(stepInfo: $0) }),
            InstructionInfo(instruction: .ora, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(instruction: .asl, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.asl(stepInfo: $0) }),
            InstructionInfo(instruction: .anc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.anc(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .ora, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(instruction: .asl, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.asl(stepInfo: $0) }),
            InstructionInfo(instruction: .slo, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(instruction: .bpl, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bpl(stepInfo: $0) }),
            InstructionInfo(instruction: .ora, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .slo, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .ora, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(instruction: .asl, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.asl(stepInfo: $0) }),
            InstructionInfo(instruction: .slo, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(instruction: .clc, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.clc(stepInfo: $0) }),
            InstructionInfo(instruction: .ora, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .slo, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .ora, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(instruction: .asl, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.asl(stepInfo: $0) }),
            InstructionInfo(instruction: .slo, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(instruction: .jsr, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.jsr(stepInfo: $0) }),
            InstructionInfo(instruction: .and, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.and(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .rla, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(instruction: .bit, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.bit(stepInfo: $0) }),
            InstructionInfo(instruction: .and, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.and(stepInfo: $0) }),
            InstructionInfo(instruction: .rol, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.rol(stepInfo: $0) }),
            InstructionInfo(instruction: .rla, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(instruction: .plp, mode: .implied,          cycles: 4, pageBoundaryCycles: 0, bytes: 1, code: { self.plp(stepInfo: $0) }),
            InstructionInfo(instruction: .and, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.and(stepInfo: $0) }),
            InstructionInfo(instruction: .rol, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.rol(stepInfo: $0) }),
            InstructionInfo(instruction: .anc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.anc(stepInfo: $0) }),
            InstructionInfo(instruction: .bit, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.bit(stepInfo: $0) }),
            InstructionInfo(instruction: .and, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.and(stepInfo: $0) }),
            InstructionInfo(instruction: .rol, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.rol(stepInfo: $0) }),
            InstructionInfo(instruction: .rla, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(instruction: .bmi, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bmi(stepInfo: $0) }),
            InstructionInfo(instruction: .and, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.and(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .rla, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .and, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.and(stepInfo: $0) }),
            InstructionInfo(instruction: .rol, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.rol(stepInfo: $0) }),
            InstructionInfo(instruction: .rla, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(instruction: .sec, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.sec(stepInfo: $0) }),
            InstructionInfo(instruction: .and, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.and(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .rla, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .and, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.and(stepInfo: $0) }),
            InstructionInfo(instruction: .rol, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.rol(stepInfo: $0) }),
            InstructionInfo(instruction: .rla, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(instruction: .rti, mode: .implied,          cycles: 6, pageBoundaryCycles: 0, bytes: 1, code: { self.rti(stepInfo: $0) }),
            InstructionInfo(instruction: .eor, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .sre, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .eor, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(instruction: .lsr, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.lsr(stepInfo: $0) }),
            InstructionInfo(instruction: .sre, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(instruction: .pha, mode: .implied,          cycles: 3, pageBoundaryCycles: 0, bytes: 1, code: { self.pha(stepInfo: $0) }),
            InstructionInfo(instruction: .eor, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(instruction: .lsr, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.lsr(stepInfo: $0) }),
            InstructionInfo(instruction: .alr, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.alr(stepInfo: $0) }),
            InstructionInfo(instruction: .jmp, mode: .absolute,         cycles: 3, pageBoundaryCycles: 0, bytes: 3, code: { self.jmp(stepInfo: $0) }),
            InstructionInfo(instruction: .eor, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(instruction: .lsr, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.lsr(stepInfo: $0) }),
            InstructionInfo(instruction: .sre, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(instruction: .bvc, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bvc(stepInfo: $0) }),
            InstructionInfo(instruction: .eor, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .sre, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .eor, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(instruction: .lsr, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.lsr(stepInfo: $0) }),
            InstructionInfo(instruction: .sre, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(instruction: .cli, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.cli(stepInfo: $0) }),
            InstructionInfo(instruction: .eor, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .sre, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .eor, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(instruction: .lsr, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.lsr(stepInfo: $0) }),
            InstructionInfo(instruction: .sre, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(instruction: .rts, mode: .implied,          cycles: 6, pageBoundaryCycles: 0, bytes: 1, code: { self.rts(stepInfo: $0) }),
            InstructionInfo(instruction: .adc, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .rra, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .adc, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(instruction: .ror, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.ror(stepInfo: $0) }),
            InstructionInfo(instruction: .rra, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(instruction: .pla, mode: .implied,          cycles: 4, pageBoundaryCycles: 0, bytes: 1, code: { self.pla(stepInfo: $0) }),
            InstructionInfo(instruction: .adc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(instruction: .ror, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.ror(stepInfo: $0) }),
            InstructionInfo(instruction: .arr, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.arr(stepInfo: $0) }),
            InstructionInfo(instruction: .jmp, mode: .indirect,         cycles: 5, pageBoundaryCycles: 0, bytes: 3, code: { self.jmp(stepInfo: $0) }),
            InstructionInfo(instruction: .adc, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(instruction: .ror, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.ror(stepInfo: $0) }),
            InstructionInfo(instruction: .rra, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(instruction: .bvs, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bvs(stepInfo: $0) }),
            InstructionInfo(instruction: .adc, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .rra, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .adc, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(instruction: .ror, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.ror(stepInfo: $0) }),
            InstructionInfo(instruction: .rra, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(instruction: .sei, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.sei(stepInfo: $0) }),
            InstructionInfo(instruction: .adc, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .rra, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .adc, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(instruction: .ror, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.ror(stepInfo: $0) }),
            InstructionInfo(instruction: .rra, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .sta, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .sax, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.sax(stepInfo: $0) }),
            InstructionInfo(instruction: .sty, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.sty(stepInfo: $0) }),
            InstructionInfo(instruction: .sta, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(instruction: .stx, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.stx(stepInfo: $0) }),
            InstructionInfo(instruction: .sax, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 0, code: { self.sax(stepInfo: $0) }),
            InstructionInfo(instruction: .dey, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.dey(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .txa, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.txa(stepInfo: $0) }),
            InstructionInfo(instruction: .xaa, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.xaa(stepInfo: $0) }),
            InstructionInfo(instruction: .sty, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.sty(stepInfo: $0) }),
            InstructionInfo(instruction: .sta, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(instruction: .stx, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.stx(stepInfo: $0) }),
            InstructionInfo(instruction: .sax, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 0, code: { self.sax(stepInfo: $0) }),
            InstructionInfo(instruction: .bcc, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bcc(stepInfo: $0) }),
            InstructionInfo(instruction: .sta, mode: .indirectYIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .ahx, mode: .indirectYIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.ahx(stepInfo: $0) }),
            InstructionInfo(instruction: .sty, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.sty(stepInfo: $0) }),
            InstructionInfo(instruction: .sta, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(instruction: .stx, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.stx(stepInfo: $0) }),
            InstructionInfo(instruction: .sax, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 0, code: { self.sax(stepInfo: $0) }),
            InstructionInfo(instruction: .tya, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.tya(stepInfo: $0) }),
            InstructionInfo(instruction: .sta, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 3, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(instruction: .txs, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.txs(stepInfo: $0) }),
            InstructionInfo(instruction: .tas, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.tas(stepInfo: $0) }),
            InstructionInfo(instruction: .shy, mode: .absoluteXIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.shy(stepInfo: $0) }),
            InstructionInfo(instruction: .sta, mode: .absoluteXIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 3, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(instruction: .shx, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.shx(stepInfo: $0) }),
            InstructionInfo(instruction: .ahx, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.ahx(stepInfo: $0) }),
            InstructionInfo(instruction: .ldy, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.ldy(stepInfo: $0) }),
            InstructionInfo(instruction: .lda, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(instruction: .ldx, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.ldx(stepInfo: $0) }),
            InstructionInfo(instruction: .lax, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(instruction: .ldy, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.ldy(stepInfo: $0) }),
            InstructionInfo(instruction: .lda, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(instruction: .ldx, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.ldx(stepInfo: $0) }),
            InstructionInfo(instruction: .lax, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(instruction: .tay, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.tay(stepInfo: $0) }),
            InstructionInfo(instruction: .lda, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(instruction: .tax, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.tax(stepInfo: $0) }),
            InstructionInfo(instruction: .lax, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(instruction: .ldy, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.ldy(stepInfo: $0) }),
            InstructionInfo(instruction: .lda, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(instruction: .ldx, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.ldx(stepInfo: $0) }),
            InstructionInfo(instruction: .lax, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(instruction: .bcs, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bcs(stepInfo: $0) }),
            InstructionInfo(instruction: .lda, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .lax, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(instruction: .ldy, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.ldy(stepInfo: $0) }),
            InstructionInfo(instruction: .lda, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(instruction: .ldx, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.ldx(stepInfo: $0) }),
            InstructionInfo(instruction: .lax, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(instruction: .clv, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.clv(stepInfo: $0) }),
            InstructionInfo(instruction: .lda, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(instruction: .tsx, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.tsx(stepInfo: $0) }),
            InstructionInfo(instruction: .las, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 0, code: { self.las(stepInfo: $0) }),
            InstructionInfo(instruction: .ldy, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.ldy(stepInfo: $0) }),
            InstructionInfo(instruction: .lda, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(instruction: .ldx, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.ldx(stepInfo: $0) }),
            InstructionInfo(instruction: .lax, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(instruction: .cpy, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.cpy(stepInfo: $0) }),
            InstructionInfo(instruction: .cmp, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .dcp, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(instruction: .cpy, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.cpy(stepInfo: $0) }),
            InstructionInfo(instruction: .cmp, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(instruction: .dec, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.dec(stepInfo: $0) }),
            InstructionInfo(instruction: .dcp, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(instruction: .iny, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.iny(stepInfo: $0) }),
            InstructionInfo(instruction: .cmp, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(instruction: .dex, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.dex(stepInfo: $0) }),
            InstructionInfo(instruction: .axs, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.axs(stepInfo: $0) }),
            InstructionInfo(instruction: .cpy, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.cpy(stepInfo: $0) }),
            InstructionInfo(instruction: .cmp, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(instruction: .dec, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.dec(stepInfo: $0) }),
            InstructionInfo(instruction: .dcp, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(instruction: .bne, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bne(stepInfo: $0) }),
            InstructionInfo(instruction: .cmp, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .dcp, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .cmp, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(instruction: .dec, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.dec(stepInfo: $0) }),
            InstructionInfo(instruction: .dcp, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(instruction: .cld, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.cld(stepInfo: $0) }),
            InstructionInfo(instruction: .cmp, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .dcp, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .cmp, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(instruction: .dec, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.dec(stepInfo: $0) }),
            InstructionInfo(instruction: .dcp, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(instruction: .cpx, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.cpx(stepInfo: $0) }),
            InstructionInfo(instruction: .sbc, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .isc, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(instruction: .cpx, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.cpx(stepInfo: $0) }),
            InstructionInfo(instruction: .sbc, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(instruction: .inc, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.inc(stepInfo: $0) }),
            InstructionInfo(instruction: .isc, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(instruction: .inx, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.inx(stepInfo: $0) }),
            InstructionInfo(instruction: .sbc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .sbc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(instruction: .cpx, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.cpx(stepInfo: $0) }),
            InstructionInfo(instruction: .sbc, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(instruction: .inc, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.inc(stepInfo: $0) }),
            InstructionInfo(instruction: .isc, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(instruction: .beq, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.beq(stepInfo: $0) }),
            InstructionInfo(instruction: .sbc, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(instruction: .isc, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .sbc, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(instruction: .inc, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.inc(stepInfo: $0) }),
            InstructionInfo(instruction: .isc, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(instruction: .sed, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.sed(stepInfo: $0) }),
            InstructionInfo(instruction: .sbc, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .isc, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(instruction: .sbc, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(instruction: .inc, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.inc(stepInfo: $0) }),
            InstructionInfo(instruction: .isc, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
        ]
    }()

    
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
    var stall: Int = 0
    
    // MARK: Reset
    
    /// Reset resets the CPU to its initial powerup state
    func reset()
    {
        self.pc = self.read16(address: 0xFFFC)
        self.sp = 0xFD
        self.set(flags: 0x24)
    }
    
    // MARK: Flag Operations
    
    /// returns a UInt8 with flag bits arranged as c,z,i,d,b,u,v,n
    private func flags() -> UInt8
    {
        let flagByte: UInt8 = UInt8.init(fromLittleEndianBitArray: [self.c, self.z, self.i, self.d, self.b, self.u, self.v, self.n])
        return flagByte
    }
    
    /// sets cpu flags from a UInt8 with bits arranged as c,z,i,d,b,u,v,n
    private func set(flags aFlags: UInt8)
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
    private func setZ(value aValue: UInt8)
    {
        self.z = (aValue == 0) ? true : false
    }
    
    /// sets the negative flag if the argument is negative (high bit is set)
    private func setN(value aValue: UInt8)
    {
        self.n = (aValue & 0x80 != 0) ? true : false
    }

    ///  sets the zero flag and the negative flag
    private func setZN(value aValue: UInt8)
    {
        self.setZ(value: aValue)
        self.setN(value: aValue)
    }
    
    /// compare two values and set zero, negative, and carry flags accordingly
    private func compare(valueA aValueA: UInt8, valueB aValueB: UInt8)
    {
        self.setZN(value: aValueA &- aValueB)
        self.c = aValueA >= aValueB ? true : false
    }
    
    // MARK: MemoryProtocol
    
    func read(address aAddress: UInt16) -> UInt8
    {
        switch aAddress {
        case 0x0000 ..< 0x2000:
            return self.ram[Int(aAddress % 0x0800)]
        case 0x2000 ..< 0x4000:
            return self.ppu?.readRegister(address: 0x2000 + (aAddress % 8)) ?? 0
        case 0x4014:
            return self.ppu?.readRegister(address: aAddress) ?? 0
        case 0x4015:
            return self.apu?.readRegister(address: aAddress) ?? 0
        case 0x4016:
            return self.controller1?.read() ?? 0
        case 0x4017:
            return self.controller2?.read() ?? 0
        case 0x4000 ..< 0x6000:
            return 0
            // TODO: I/O registers
        case 0x6000 ... 0xFFFF:
            return self.mapper?.cpuRead(address: aAddress) ?? 0
        default:
            return 0
        }
    }
    
    func write(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress {
        case 0x0000 ..< 0x2000:
            self.ram[Int(aAddress % 0x0800)] = aValue
        case 0x2000 ..< 0x4000:
            self.ppu?.writeRegister(address: 0x2000 + (aAddress % 8), value: aValue)
        case 0x4000 ..< 0x4014:
            self.apu?.writeRegister(address: aAddress, value: aValue)
        case 0x4014:
            let startIndex: Int = Int(UInt16(aValue) << 8)
            self.ppu?.writeOAMDMA(oamDMA: [UInt8](self.ram[startIndex ..< startIndex + 256]))
            self.stall += (self.cycles % 2 == 0) ? 513 : 514
        case 0x4015:
            self.apu?.writeRegister(address: aAddress, value: aValue)
        case 0x4016:
            self.controller1?.write(value: aValue)
            self.controller2?.write(value: aValue)
        case 0x4017:
            self.apu?.writeRegister(address: aAddress, value: aValue)
        case 0x4000 ..< 0x6000:
            // TODO: I/O registers
            break
        case 0x6000 ... 0xFFFF:
            self.mapper?.cpuWrite(address: aAddress, value: aValue)
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
    private func read16(address aAddress: UInt16) -> UInt16
    {
        let lo: UInt16 = UInt16(self.read(address: aAddress))
        let hi: UInt16 = UInt16(self.read(address: aAddress &+ 1))
        return (hi << 8) | lo
    }

    /// emulates a 6502 bug that caused the low byte to wrap without incrementing the high byte
    private func read16bug(address aAddress: UInt16) -> UInt16
    {
        let a: UInt16 = aAddress
        let b: UInt16 = (a & 0xFF00) | UInt16((a % 256) &+ 1)
        let lo = self.read(address: a)
        let hi = self.read(address: b)
        return (UInt16(hi) << 8) | UInt16(lo)
    }
    
    // MARK: Stack
    
    /// pushes a byte onto the stack
    private func push(value aValue: UInt8)
    {
        self.write(address: 0x100 | UInt16(self.sp), value: aValue)
        self.sp &-= 1
    }

    /// pops a byte from the stack
    private func pull() -> UInt8
    {
        self.sp &+= 1
        return self.read(address: 0x100 | UInt16(self.sp))
    }

    /// pushes two bytes onto the stack
    private func push16(value aValue: UInt16)
    {
        let hi: UInt8 = UInt8(aValue >> 8)
        let lo: UInt8 = UInt8(aValue & 0xFF)
        self.push(value: hi)
        self.push(value: lo)
    }

    // pull16 pops two bytes from the stack
    private func pull16() -> UInt16
    {
        let lo: UInt16 = UInt16(self.pull())
        let hi: UInt16 = UInt16(self.pull())
        return (hi << 8) | lo
    }
    
    // MARK: Interrupt Operations
    
    /// causes a non-maskable interrupt to occur on the next cycle
    func triggerNMI()
    {
        self.interrupt = .nmi
    }

    /// causes an IRQ interrupt to occur on the next cycle, if the interrupt disable flag is not set
    func triggerIRQ()
    {
        if self.i == false
        {
            self.interrupt = .irq
        }
    }
    
    // MARK: Timing
    
    /// adds a cycle for taking a branch and adds another cycle if the branch jumps to a new page
    private func addBranchCycles(stepInfo aStepInfo: StepInfo)
    {
        self.cycles &+= 1
        if self.pagesDiffer(address1: aStepInfo.pc, address2: aStepInfo.address)
        {
            self.cycles &+= 1
        }
    }
    
    /// NMI - Non-Maskable Interrupt
    private func nmi()
    {
        self.push16(value: self.pc)
        self.php(stepInfo: StepInfo(address: 0, pc: 0, mode: .implied))
        self.pc = self.read16(address: 0xFFFA)
        self.i = true
        self.cycles &+= 7
    }

    /// IRQ - IRQ Interrupt
    private func irq()
    {
        self.push16(value: self.pc)
        self.php(stepInfo: StepInfo(address: 0, pc: 0, mode: .implied)) // placeholder StepInfo value (unused)
        self.pc = self.read16(address: 0xFFFE)
        self.i = true
        self.cycles &+= 7
    }
    
    /// executes a single CPU instruction
    func step() -> Int
    {
        if self.stall > 0
        {
            self.stall -= 1
            return 1
        }

        let cycles = self.cycles

        switch self.interrupt
        {
        case .nmi:
            self.nmi()
        case .irq:
            self.irq()
        default: break
        }
        self.interrupt = .none

        let opcode = self.read(address: self.pc)
        let instructioninfo: InstructionInfo = self.instructionTable[Int(opcode)]
        let mode: AddressingMode = instructioninfo.mode
        var address: UInt16
        var pageCrossed: Bool = false
        switch mode
        {
        case .absolute:
            address = self.read16(address: self.pc &+ 1)
        case .absoluteXIndexed:
            address = self.read16(address: self.pc &+ 1) &+ UInt16(self.x)
            pageCrossed = self.pagesDiffer(address1: address &- UInt16(self.x), address2: address)
        case .absoluteYIndexed:
            address = self.read16(address: self.pc &+ 1) &+ UInt16(self.y)
            pageCrossed = self.pagesDiffer(address1: address &- UInt16(self.y), address2: address)
        case .accumulator:
            address = 0
        case .immediate:
            address = self.pc &+ 1
        case .implied:
            address = 0
        case .xIndexedIndirect:
            address = self.read16bug(address: UInt16(self.read(address: self.pc &+ 1) &+ self.x))
        case .indirect:
            address = self.read16bug(address: self.read16(address: self.pc &+ 1))
        case .indirectYIndexed:
            address = self.read16bug(address: UInt16(self.read(address: self.pc &+ 1))) &+ UInt16(self.y)
            pageCrossed = self.pagesDiffer(address1: address &- UInt16(self.y), address2: address)
        case .relative:
            let offset = UInt16(self.read(address: self.pc &+ 1))
            if offset < 0x80 {
                address = self.pc &+ 2 &+ offset
            } else {
                address = self.pc &+ 2 &+ offset &- 0x100
            }
        case .zeropage:
            address = UInt16(self.read(address: self.pc &+ 1))
        case .zeroPageXIndexed:
            address = UInt16(self.read(address: self.pc &+ 1) &+ self.x) & 0xff
        case .zeroPageYIndexed:
            address = UInt16(self.read(address: self.pc &+ 1) &+ self.y) & 0xff
        }

        self.pc &+= UInt16(instructioninfo.bytes)
        self.cycles &+= UInt64(instructioninfo.cycles)
        if pageCrossed
        {
            self.cycles &+= UInt64(instructioninfo.pageBoundaryCycles)
        }
        let info: StepInfo = StepInfo(address: address, pc: self.pc, mode: mode)
        instructioninfo.code(info)

        return Int(self.cycles - cycles)
    }
    
    // MARK: 6502 functions
    
    /// ADC - Add with Carry
    private func adc(stepInfo aStepInfo: StepInfo)
    {
        let a: UInt8 = self.a
        let b: UInt8 = self.read(address: aStepInfo.address)
        let c: UInt8 = self.c ? 1 : 0
        self.a = a &+ b &+ c
        self.setZN(value: self.a)
        if Int(a) + Int(b) + Int(c) > 0xFF
        {
            self.c = true
        }
        else
        {
            self.c = false
        }
        
        if ((a ^ b) & 0x80) == 0 && ((a ^ self.a) & 0x80) != 0
        {
            self.v = true
        }
        else
        {
            self.v = false
        }
    }

    /// AND - Logical AND
    private func and(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.a & self.read(address: aStepInfo.address)
        self.setZN(value: self.a)
    }

    /// ASL - Arithmetic Shift Left
    private func asl(stepInfo aStepInfo: StepInfo)
    {
        if aStepInfo.mode == .accumulator
        {
            self.c = ((self.a >> 7) & 1) == 1
            self.a <<= 1
            self.setZN(value: self.a)
        }
        else
        {
            var value = self.read(address: aStepInfo.address)
            self.c = ((value >> 7) & 1) == 1
            value <<= 1
            self.write(address: aStepInfo.address, value: value)
            self.setZN(value: value)
        }
    }

    /// BCC - Branch if Carry Clear
    private func bcc(stepInfo aStepInfo: StepInfo)
    {
        if self.c == false
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BCS - Branch if Carry Set
    private func bcs(stepInfo aStepInfo: StepInfo)
    {
        if self.c == true
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BEQ - Branch if Equal
    private func beq(stepInfo aStepInfo: StepInfo)
    {
        if self.z == true
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BIT - Bit Test
    private func bit(stepInfo aStepInfo: StepInfo)
    {
        let value = self.read(address: aStepInfo.address)
        self.v = ((value >> 6) & 1) == 1
        self.setZ(value: value & self.a)
        self.setN(value: value)
    }

    /// BMI - Branch if Minus
    private func bmi(stepInfo aStepInfo: StepInfo)
    {
        if self.n == true
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BNE - Branch if Not Equal
    private func bne(stepInfo aStepInfo: StepInfo)
    {
        if self.z == false
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BPL - Branch if Positive
    private func bpl(stepInfo aStepInfo: StepInfo)
    {
        if self.n == false
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }
    
    /// BRK - Force Interrupt
    private func brk(stepInfo aStepInfo: StepInfo)
    {
        self.push16(value: self.pc)
        self.php(stepInfo: aStepInfo)
        self.sei(stepInfo: aStepInfo)
        self.pc = self.read16(address: 0xFFFE)
    }
    
    /// BVC - Branch if Overflow Clear
    private func bvc(stepInfo aStepInfo: StepInfo)
    {
        if self.v == false
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BVS - Branch if Overflow Set
    private func bvs(stepInfo aStepInfo: StepInfo)
    {
        if self.v == true
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// CLC - Clear Carry Flag
    private func clc(stepInfo aStepInfo: StepInfo)
    {
        self.c = false
    }

    /// CLD - Clear Decimal Mode
    private func cld(stepInfo aStepInfo: StepInfo)
    {
        self.d = false
    }

    /// CLI - Clear Interrupt Disable
    private func cli(stepInfo aStepInfo: StepInfo)
    {
        self.i = false
    }

    /// CLV - Clear Overflow Flag
    private func clv(stepInfo aStepInfo: StepInfo)
    {
        self.v = false
    }

    /// CMP - Compare
    private func cmp(stepInfo aStepInfo: StepInfo)
    {
        let value = self.read(address: aStepInfo.address)
        self.compare(valueA: self.a, valueB: value)
    }

    /// CPX - Compare X Register
    private func cpx(stepInfo aStepInfo: StepInfo)
    {
        let value = self.read(address: aStepInfo.address)
        self.compare(valueA: self.x, valueB: value)
    }

    /// CPY - Compare Y Register
    private func cpy(stepInfo aStepInfo: StepInfo)
    {
        let value = self.read(address: aStepInfo.address)
        self.compare(valueA: self.y, valueB: value)
    }

    /// DEC - Decrement Memory
    private func dec(stepInfo aStepInfo: StepInfo)
    {
        let value = self.read(address: aStepInfo.address) &- 1
        self.write(address: aStepInfo.address, value: value)
        self.setZN(value: value)
    }

    /// DEX - Decrement X Register
    private func dex(stepInfo aStepInfo: StepInfo)
    {
        self.x &-= 1 // decrement and wrap if needed
        self.setZN(value: self.x)
    }

    /// DEY - Decrement Y Register
    private func dey(stepInfo aStepInfo: StepInfo)
    {
        self.y &-= 1 // decrement and wrap if needed
        self.setZN(value: self.y)
    }

    /// EOR - Exclusive OR
    private func eor(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.a ^ self.read(address: aStepInfo.address)
        self.setZN(value: self.a)
    }

    /// INC - Increment Memory
    private func inc(stepInfo aStepInfo: StepInfo)
    {
        let value: UInt8 = self.read(address: aStepInfo.address) &+ 1 // wrap if needed
        self.write(address: aStepInfo.address, value: value)
        self.setZN(value: value)
    }

    /// INX - Increment X Register
    private func inx(stepInfo aStepInfo: StepInfo)
    {
        self.x &+= 1 // increment and wrap if needed
        self.setZN(value: self.x)
    }

    /// INY - Increment Y Register
    private func iny(stepInfo aStepInfo: StepInfo)
    {
        
        self.y &+= 1 // increment and wrap if needed
        self.setZN(value: self.y)
    }

    /// JMP - Jump
    private func jmp(stepInfo aStepInfo: StepInfo)
    {
        self.pc = aStepInfo.address
    }

    /// JSR - Jump to Subroutine
    private func jsr(stepInfo aStepInfo: StepInfo)
    {
        self.push16(value: self.pc - 1)
        self.pc = aStepInfo.address
    }

    /// LDA - Load Accumulator
    private func lda(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.read(address: aStepInfo.address)
        self.setZN(value: self.a)
    }

    /// LDX - Load X Register
    private func ldx(stepInfo aStepInfo: StepInfo)
    {
        self.x = self.read(address: aStepInfo.address)
        self.setZN(value: self.x)
    }

    /// LDY - Load Y Register
    private func ldy(stepInfo aStepInfo: StepInfo)
    {
        self.y = self.read(address: aStepInfo.address)
        self.setZN(value: self.y)
    }

    /// LSR - Logical Shift Right
    private func lsr(stepInfo aStepInfo: StepInfo)
    {
        if aStepInfo.mode == .accumulator
        {
            self.c = (self.a & 1) == 1
            self.a >>= 1
            self.setZN(value: self.a)
        }
        else
        {
            var value = self.read(address: aStepInfo.address)
            self.c = (value & 1) == 1
            value >>= 1
            self.write(address: aStepInfo.address, value: value)
            self.setZN(value: value)
        }
    }

    /// NOP - No Operation
    private func nop(stepInfo aStepInfo: StepInfo)
    {
        // do nothing
    }

    /// ORA - Logical Inclusive OR
    private func ora(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.a | self.read(address: aStepInfo.address)
        self.setZN(value: self.a)
    }

    /// PHA - Push Accumulator
    private func pha(stepInfo aStepInfo: StepInfo)
    {
        self.push(value: self.a)
    }

    /// PHP - Push Processor Status
    private func php(stepInfo aStepInfo: StepInfo)
    {
        self.push(value: self.flags() | 0x10)
    }

    /// PLA - Pull Accumulator
    private func pla(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.pull()
        self.setZN(value: self.a)
    }

    /// PLP - Pull Processor Status
    private func plp(stepInfo aStepInfo: StepInfo)
    {
        self.set(flags: (self.pull() & 0xEF) | 0x20)
    }

    /// ROL - Rotate Left
    private func rol(stepInfo aStepInfo: StepInfo)
    {
        if aStepInfo.mode == .accumulator
        {
            let c: UInt8 = self.c ? 1 : 0
            self.c = ((self.a >> 7) & 1) == 1
            self.a = (self.a << 1) | c
            self.setZN(value: self.a)
        }
        else
        {
            let c: UInt8 = self.c ? 1 : 0
            var value = self.read(address: aStepInfo.address)
            self.c = ((value >> 7) & 1) == 1
            value = (value << 1) | c
            self.write(address: aStepInfo.address, value: value)
            self.setZN(value: value)
        }
    }

    /// ROR - Rotate Right
    private func ror(stepInfo aStepInfo: StepInfo)
    {
        if aStepInfo.mode == .accumulator
        {
            let c: UInt8 = self.c ? 1 : 0
            self.c = (self.a & 1) == 1
            self.a = (self.a >> 1) | (c << 7)
            self.setZN(value: self.a)
        }
        else
        {
            let c: UInt8 = self.c ? 1 : 0
            var value = self.read(address: aStepInfo.address)
            self.c = (value & 1) == 1
            value = (value >> 1) | (c << 7)
            self.write(address: aStepInfo.address, value: value)
            self.setZN(value: value)
        }
    }

    /// RTI - Return from Interrupt
    private func rti(stepInfo aStepInfo: StepInfo)
    {
        self.set(flags: (self.pull() & 0xEF) | 0x20)
        self.pc = self.pull16()
    }

    /// RTS - Return from Subroutine
    private func rts(stepInfo aStepInfo: StepInfo)
    {
        self.pc = self.pull16() &+ 1
    }

    /// SBC - Subtract with Carry
    private func sbc(stepInfo aStepInfo: StepInfo)
    {
        let a: UInt8 = self.a
        let b: UInt8 = self.read(address: aStepInfo.address)
        let c: UInt8 = self.c ? 1 : 0
        self.a = a &- b &- (1 - c)
        self.setZN(value: self.a)
        if Int(a) - Int(b) - Int(1 - c) >= 0
        {
            self.c = true
        }
        else
        {
            self.c = false
        }
        
        if ((a ^ b) & 0x80) != 0 && ((a ^ self.a) & 0x80) != 0
        {
            self.v = true
        }
        else
        {
            self.v = false
        }
    }

    /// SEC - Set Carry Flag
    private func sec(stepInfo aStepInfo: StepInfo)
    {
        self.c = true
    }

    /// SED - Set Decimal Flag
    private func sed(stepInfo aStepInfo: StepInfo)
    {
        self.d = true
    }

    /// SEI - Set Interrupt Disable
    private func sei(stepInfo aStepInfo: StepInfo)
    {
        self.i = true
    }

    /// STA - Store Accumulator
    private func sta(stepInfo aStepInfo: StepInfo)
    {
        self.write(address: aStepInfo.address, value: self.a)
    }

    /// STX - Store X Register
    private func stx(stepInfo aStepInfo: StepInfo)
    {
        self.write(address: aStepInfo.address, value: self.x)
    }

    /// STY - Store Y Register
    private func sty(stepInfo aStepInfo: StepInfo)
    {
        self.write(address: aStepInfo.address, value: self.y)
    }

    /// TAX - Transfer Accumulator to X
    private func tax(stepInfo aStepInfo: StepInfo)
    {
        self.x = self.a
        self.setZN(value: self.x)
    }

    /// TAY - Transfer Accumulator to Y
    private func tay(stepInfo aStepInfo: StepInfo)
    {
        self.y = self.a
        self.setZN(value: self.y)
    }

    /// TSX - Transfer Stack Pointer to X
    private func tsx(stepInfo aStepInfo: StepInfo)
    {
        self.x = self.sp
        self.setZN(value: self.x)
    }

    /// TXA - Transfer X to Accumulator
    private func txa(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.x
        self.setZN(value: self.a)
    }

    /// TXS - Transfer X to Stack Pointer
    private func txs(stepInfo aStepInfo: StepInfo)
    {
        self.sp = self.x
    }

    /// TYA - Transfer Y to Accumulator
    private func tya(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.y
        self.setZN(value: self.a)
    }
    
    // MARK: Illegal Instructions

    private func ahx(stepInfo aStepInfo: StepInfo) {}
    private func alr(stepInfo aStepInfo: StepInfo) {}
    private func anc(stepInfo aStepInfo: StepInfo) {}
    private func arr(stepInfo aStepInfo: StepInfo) {}
    private func axs(stepInfo aStepInfo: StepInfo) {}
    private func dcp(stepInfo aStepInfo: StepInfo) {}
    private func isc(stepInfo aStepInfo: StepInfo) {}
    private func kil(stepInfo aStepInfo: StepInfo) {}
    private func las(stepInfo aStepInfo: StepInfo) {}
    private func lax(stepInfo aStepInfo: StepInfo) {}
    private func rla(stepInfo aStepInfo: StepInfo) {}
    private func rra(stepInfo aStepInfo: StepInfo) {}
    private func sax(stepInfo aStepInfo: StepInfo) {}
    private func shx(stepInfo aStepInfo: StepInfo) {}
    private func shy(stepInfo aStepInfo: StepInfo) {}
    private func slo(stepInfo aStepInfo: StepInfo) {}
    private func sre(stepInfo aStepInfo: StepInfo) {}
    private func tas(stepInfo aStepInfo: StepInfo) {}
    private func xaa(stepInfo aStepInfo: StepInfo) {}
}

enum Instruction
{
    case brk, ora, asl, php, bpl, clc, jsr, and, bit, rol, plp, bmi, sec, rti, eor, lsr, pha, jmp, bvc, cli, rts, adc, ror, pla, bvs, sei, sta, sty, stx, dey, txa, bcc, tya, txs, ldy, lda, ldx, tay, tax, bcs, clv, tsx, cpy, cmp, dec, iny, dex, bne, cld, cpx, sbc, inc, inx, nop, beq, sed, kil, slo, anc, rla, sre, alr, rra, arr, sax, xaa, ahx, tas, shy, shx, lax, las, dcp, axs, isc
}

enum AddressingMode: UInt8
{
    case absolute, absoluteXIndexed, absoluteYIndexed, accumulator, immediate, implied, xIndexedIndirect, indirect, indirectYIndexed, relative, zeropage, zeroPageXIndexed, zeroPageYIndexed
}

enum Interrupt
{
    case none, nmi, irq
}
