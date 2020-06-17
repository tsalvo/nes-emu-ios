//
//  CPU.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/4/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

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
    /// the unique opcode for this combination of instruction and addressing mode
    let opCode: UInt8
    
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
    var stall: Int { get set }
}

/// NES Central processing unit
class CPU: CPUProtocol
{
    static let frequency: Int = 1789773
    
    weak var console: ConsoleProtocol?
    weak var controller1: ControllerProtocol?
    weak var controller2: ControllerProtocol?
    
    init(ppu aPPU: PPU, apu aAPU: APU, mapper aMapper: MapperProtocol?, controller1 aController1: ControllerProtocol?, controller2 aController2: ControllerProtocol?)
    {
        self.apu = aAPU
        self.ppu = aPPU
        self.mapper = aMapper
        self.controller1 = aController1
        self.controller2 = aController2
    }
    
    private weak var apu: APU?
    private weak var ppu: PPU?
    private weak var mapper: MapperProtocol?
    
    /// 2KB RAM
    private var ram: [UInt8] = [UInt8].init(repeating: 0, count: 2048)
    
    /// all 6502 op codes, containing all combinations of instructions and their associated addressing mode(s).  some op codes point to "illegal" instructions (such as slo, kil, anc, rla, sre, alr, rra, arr, sax, xaa, ahx, tas, shy, shx, lax, las, dcp, axs, isc) which won't do anything
    private lazy var instructionTable: [InstructionInfo] = {
        [
            InstructionInfo(opCode: 0x00, instruction: .brk, mode: .implied,          cycles: 7, pageBoundaryCycles: 0, bytes: 2, code: { self.brk(stepInfo: $0) }),
            InstructionInfo(opCode: 0x01, instruction: .ora, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(opCode: 0x02, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0x03, instruction: .slo, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(opCode: 0x04, instruction: .nop, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x05, instruction: .ora, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(opCode: 0x06, instruction: .asl, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.asl(stepInfo: $0) }),
            InstructionInfo(opCode: 0x07, instruction: .slo, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(opCode: 0x08, instruction: .php, mode: .implied,          cycles: 3, pageBoundaryCycles: 0, bytes: 1, code: { self.php(stepInfo: $0) }),
            InstructionInfo(opCode: 0x09, instruction: .ora, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(opCode: 0x0A, instruction: .asl, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.asl(stepInfo: $0) }),
            InstructionInfo(opCode: 0x0B, instruction: .anc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.anc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x0C, instruction: .nop, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x0D, instruction: .ora, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(opCode: 0x0E, instruction: .asl, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.asl(stepInfo: $0) }),
            InstructionInfo(opCode: 0x0F, instruction: .slo, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(opCode: 0x10, instruction: .bpl, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bpl(stepInfo: $0) }),
            InstructionInfo(opCode: 0x11, instruction: .ora, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(opCode: 0x12, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0x13, instruction: .slo, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(opCode: 0x14, instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x15, instruction: .ora, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(opCode: 0x16, instruction: .asl, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.asl(stepInfo: $0) }),
            InstructionInfo(opCode: 0x17, instruction: .slo, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(opCode: 0x18, instruction: .clc, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.clc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x19, instruction: .ora, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(opCode: 0x1A, instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x1B, instruction: .slo, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(opCode: 0x1C, instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x1D, instruction: .ora, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.ora(stepInfo: $0) }),
            InstructionInfo(opCode: 0x1E, instruction: .asl, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.asl(stepInfo: $0) }),
            InstructionInfo(opCode: 0x1F, instruction: .slo, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.slo(stepInfo: $0) }),
            InstructionInfo(opCode: 0x20, instruction: .jsr, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.jsr(stepInfo: $0) }),
            InstructionInfo(opCode: 0x21, instruction: .and, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.and(stepInfo: $0) }),
            InstructionInfo(opCode: 0x22, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0x23, instruction: .rla, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(opCode: 0x24, instruction: .bit, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.bit(stepInfo: $0) }),
            InstructionInfo(opCode: 0x25, instruction: .and, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.and(stepInfo: $0) }),
            InstructionInfo(opCode: 0x26, instruction: .rol, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.rol(stepInfo: $0) }),
            InstructionInfo(opCode: 0x27, instruction: .rla, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(opCode: 0x28, instruction: .plp, mode: .implied,          cycles: 4, pageBoundaryCycles: 0, bytes: 1, code: { self.plp(stepInfo: $0) }),
            InstructionInfo(opCode: 0x29, instruction: .and, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.and(stepInfo: $0) }),
            InstructionInfo(opCode: 0x2A, instruction: .rol, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.rol(stepInfo: $0) }),
            InstructionInfo(opCode: 0x2B, instruction: .anc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.anc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x2C, instruction: .bit, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.bit(stepInfo: $0) }),
            InstructionInfo(opCode: 0x2D, instruction: .and, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.and(stepInfo: $0) }),
            InstructionInfo(opCode: 0x2E, instruction: .rol, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.rol(stepInfo: $0) }),
            InstructionInfo(opCode: 0x2F, instruction: .rla, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(opCode: 0x30, instruction: .bmi, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bmi(stepInfo: $0) }),
            InstructionInfo(opCode: 0x31, instruction: .and, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.and(stepInfo: $0) }),
            InstructionInfo(opCode: 0x32, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0x33, instruction: .rla, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(opCode: 0x34, instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x35, instruction: .and, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.and(stepInfo: $0) }),
            InstructionInfo(opCode: 0x36, instruction: .rol, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.rol(stepInfo: $0) }),
            InstructionInfo(opCode: 0x37, instruction: .rla, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(opCode: 0x38, instruction: .sec, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.sec(stepInfo: $0) }),
            InstructionInfo(opCode: 0x39, instruction: .and, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.and(stepInfo: $0) }),
            InstructionInfo(opCode: 0x3A, instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x3B, instruction: .rla, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(opCode: 0x3C, instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x3D, instruction: .and, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.and(stepInfo: $0) }),
            InstructionInfo(opCode: 0x3E, instruction: .rol, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.rol(stepInfo: $0) }),
            InstructionInfo(opCode: 0x3F, instruction: .rla, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.rla(stepInfo: $0) }),
            InstructionInfo(opCode: 0x40, instruction: .rti, mode: .implied,          cycles: 6, pageBoundaryCycles: 0, bytes: 1, code: { self.rti(stepInfo: $0) }),
            InstructionInfo(opCode: 0x41, instruction: .eor, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(opCode: 0x42, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0x43, instruction: .sre, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(opCode: 0x44, instruction: .nop, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x45, instruction: .eor, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(opCode: 0x46, instruction: .lsr, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.lsr(stepInfo: $0) }),
            InstructionInfo(opCode: 0x47, instruction: .sre, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(opCode: 0x48, instruction: .pha, mode: .implied,          cycles: 3, pageBoundaryCycles: 0, bytes: 1, code: { self.pha(stepInfo: $0) }),
            InstructionInfo(opCode: 0x49, instruction: .eor, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(opCode: 0x4A, instruction: .lsr, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.lsr(stepInfo: $0) }),
            InstructionInfo(opCode: 0x4B, instruction: .alr, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.alr(stepInfo: $0) }),
            InstructionInfo(opCode: 0x4C, instruction: .jmp, mode: .absolute,         cycles: 3, pageBoundaryCycles: 0, bytes: 3, code: { self.jmp(stepInfo: $0) }),
            InstructionInfo(opCode: 0x4D, instruction: .eor, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(opCode: 0x4E, instruction: .lsr, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.lsr(stepInfo: $0) }),
            InstructionInfo(opCode: 0x4F, instruction: .sre, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(opCode: 0x50, instruction: .bvc, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bvc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x51, instruction: .eor, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(opCode: 0x52, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0x53, instruction: .sre, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(opCode: 0x54, instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x55, instruction: .eor, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(opCode: 0x56, instruction: .lsr, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.lsr(stepInfo: $0) }),
            InstructionInfo(opCode: 0x57, instruction: .sre, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(opCode: 0x58, instruction: .cli, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.cli(stepInfo: $0) }),
            InstructionInfo(opCode: 0x59, instruction: .eor, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(opCode: 0x5A, instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x5B, instruction: .sre, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(opCode: 0x5C, instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x5D, instruction: .eor, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.eor(stepInfo: $0) }),
            InstructionInfo(opCode: 0x5E, instruction: .lsr, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.lsr(stepInfo: $0) }),
            InstructionInfo(opCode: 0x5F, instruction: .sre, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.sre(stepInfo: $0) }),
            InstructionInfo(opCode: 0x60, instruction: .rts, mode: .implied,          cycles: 6, pageBoundaryCycles: 0, bytes: 1, code: { self.rts(stepInfo: $0) }),
            InstructionInfo(opCode: 0x61, instruction: .adc, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x62, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0x63, instruction: .rra, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(opCode: 0x64, instruction: .nop, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x65, instruction: .adc, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x66, instruction: .ror, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.ror(stepInfo: $0) }),
            InstructionInfo(opCode: 0x67, instruction: .rra, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(opCode: 0x68, instruction: .pla, mode: .implied,          cycles: 4, pageBoundaryCycles: 0, bytes: 1, code: { self.pla(stepInfo: $0) }),
            InstructionInfo(opCode: 0x69, instruction: .adc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x6A, instruction: .ror, mode: .accumulator,      cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.ror(stepInfo: $0) }),
            InstructionInfo(opCode: 0x6B, instruction: .arr, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.arr(stepInfo: $0) }),
            InstructionInfo(opCode: 0x6C, instruction: .jmp, mode: .indirect,         cycles: 5, pageBoundaryCycles: 0, bytes: 3, code: { self.jmp(stepInfo: $0) }),
            InstructionInfo(opCode: 0x6D, instruction: .adc, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x6E, instruction: .ror, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.ror(stepInfo: $0) }),
            InstructionInfo(opCode: 0x6F, instruction: .rra, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(opCode: 0x70, instruction: .bvs, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bvs(stepInfo: $0) }),
            InstructionInfo(opCode: 0x71, instruction: .adc, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x72, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0x73, instruction: .rra, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(opCode: 0x74, instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x75, instruction: .adc, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x76, instruction: .ror, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.ror(stepInfo: $0) }),
            InstructionInfo(opCode: 0x77, instruction: .rra, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(opCode: 0x78, instruction: .sei, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.sei(stepInfo: $0) }),
            InstructionInfo(opCode: 0x79, instruction: .adc, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x7A, instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x7B, instruction: .rra, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(opCode: 0x7C, instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x7D, instruction: .adc, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.adc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x7E, instruction: .ror, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.ror(stepInfo: $0) }),
            InstructionInfo(opCode: 0x7F, instruction: .rra, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.rra(stepInfo: $0) }),
            InstructionInfo(opCode: 0x80, instruction: .nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x81, instruction: .sta, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(opCode: 0x82, instruction: .nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x83, instruction: .sax, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.sax(stepInfo: $0) }),
            InstructionInfo(opCode: 0x84, instruction: .sty, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.sty(stepInfo: $0) }),
            InstructionInfo(opCode: 0x85, instruction: .sta, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(opCode: 0x86, instruction: .stx, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.stx(stepInfo: $0) }),
            InstructionInfo(opCode: 0x87, instruction: .sax, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 0, code: { self.sax(stepInfo: $0) }),
            InstructionInfo(opCode: 0x88, instruction: .dey, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.dey(stepInfo: $0) }),
            InstructionInfo(opCode: 0x89, instruction: .nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0x8A, instruction: .txa, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.txa(stepInfo: $0) }),
            InstructionInfo(opCode: 0x8B, instruction: .xaa, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.xaa(stepInfo: $0) }),
            InstructionInfo(opCode: 0x8C, instruction: .sty, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.sty(stepInfo: $0) }),
            InstructionInfo(opCode: 0x8D, instruction: .sta, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(opCode: 0x8E, instruction: .stx, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.stx(stepInfo: $0) }),
            InstructionInfo(opCode: 0x8F, instruction: .sax, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 0, code: { self.sax(stepInfo: $0) }),
            InstructionInfo(opCode: 0x90, instruction: .bcc, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bcc(stepInfo: $0) }),
            InstructionInfo(opCode: 0x91, instruction: .sta, mode: .indirectYIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(opCode: 0x92, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0x93, instruction: .ahx, mode: .indirectYIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.ahx(stepInfo: $0) }),
            InstructionInfo(opCode: 0x94, instruction: .sty, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.sty(stepInfo: $0) }),
            InstructionInfo(opCode: 0x95, instruction: .sta, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(opCode: 0x96, instruction: .stx, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.stx(stepInfo: $0) }),
            InstructionInfo(opCode: 0x97, instruction: .sax, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 0, code: { self.sax(stepInfo: $0) }),
            InstructionInfo(opCode: 0x98, instruction: .tya, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.tya(stepInfo: $0) }),
            InstructionInfo(opCode: 0x99, instruction: .sta, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 3, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(opCode: 0x9A, instruction: .txs, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.txs(stepInfo: $0) }),
            InstructionInfo(opCode: 0x9B, instruction: .tas, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.tas(stepInfo: $0) }),
            InstructionInfo(opCode: 0x9C, instruction: .shy, mode: .absoluteXIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.shy(stepInfo: $0) }),
            InstructionInfo(opCode: 0x9D, instruction: .sta, mode: .absoluteXIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 3, code: { self.sta(stepInfo: $0) }),
            InstructionInfo(opCode: 0x9E, instruction: .shx, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.shx(stepInfo: $0) }),
            InstructionInfo(opCode: 0x9F, instruction: .ahx, mode: .absoluteYIndexed, cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.ahx(stepInfo: $0) }),
            InstructionInfo(opCode: 0xA0, instruction: .ldy, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.ldy(stepInfo: $0) }),
            InstructionInfo(opCode: 0xA1, instruction: .lda, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(opCode: 0xA2, instruction: .ldx, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.ldx(stepInfo: $0) }),
            InstructionInfo(opCode: 0xA3, instruction: .lax, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(opCode: 0xA4, instruction: .ldy, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.ldy(stepInfo: $0) }),
            InstructionInfo(opCode: 0xA5, instruction: .lda, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(opCode: 0xA6, instruction: .ldx, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.ldx(stepInfo: $0) }),
            InstructionInfo(opCode: 0xA7, instruction: .lax, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(opCode: 0xA8, instruction: .tay, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.tay(stepInfo: $0) }),
            InstructionInfo(opCode: 0xA9, instruction: .lda, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(opCode: 0xAA, instruction: .tax, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.tax(stepInfo: $0) }),
            InstructionInfo(opCode: 0xAB, instruction: .lax, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(opCode: 0xAC, instruction: .ldy, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.ldy(stepInfo: $0) }),
            InstructionInfo(opCode: 0xAD, instruction: .lda, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(opCode: 0xAE, instruction: .ldx, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.ldx(stepInfo: $0) }),
            InstructionInfo(opCode: 0xAF, instruction: .lax, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(opCode: 0xB0, instruction: .bcs, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bcs(stepInfo: $0) }),
            InstructionInfo(opCode: 0xB1, instruction: .lda, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(opCode: 0xB2, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0xB3, instruction: .lax, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(opCode: 0xB4, instruction: .ldy, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.ldy(stepInfo: $0) }),
            InstructionInfo(opCode: 0xB5, instruction: .lda, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(opCode: 0xB6, instruction: .ldx, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.ldx(stepInfo: $0) }),
            InstructionInfo(opCode: 0xB7, instruction: .lax, mode: .zeroPageYIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(opCode: 0xB8, instruction: .clv, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.clv(stepInfo: $0) }),
            InstructionInfo(opCode: 0xB9, instruction: .lda, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(opCode: 0xBA, instruction: .tsx, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.tsx(stepInfo: $0) }),
            InstructionInfo(opCode: 0xBB, instruction: .las, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 0, code: { self.las(stepInfo: $0) }),
            InstructionInfo(opCode: 0xBC, instruction: .ldy, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.ldy(stepInfo: $0) }),
            InstructionInfo(opCode: 0xBD, instruction: .lda, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.lda(stepInfo: $0) }),
            InstructionInfo(opCode: 0xBE, instruction: .ldx, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.ldx(stepInfo: $0) }),
            InstructionInfo(opCode: 0xBF, instruction: .lax, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 0, code: { self.lax(stepInfo: $0) }),
            InstructionInfo(opCode: 0xC0, instruction: .cpy, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.cpy(stepInfo: $0) }),
            InstructionInfo(opCode: 0xC1, instruction: .cmp, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xC2, instruction: .nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0xC3, instruction: .dcp, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xC4, instruction: .cpy, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.cpy(stepInfo: $0) }),
            InstructionInfo(opCode: 0xC5, instruction: .cmp, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xC6, instruction: .dec, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.dec(stepInfo: $0) }),
            InstructionInfo(opCode: 0xC7, instruction: .dcp, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xC8, instruction: .iny, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.iny(stepInfo: $0) }),
            InstructionInfo(opCode: 0xC9, instruction: .cmp, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xCA, instruction: .dex, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.dex(stepInfo: $0) }),
            InstructionInfo(opCode: 0xCB, instruction: .axs, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.axs(stepInfo: $0) }),
            InstructionInfo(opCode: 0xCC, instruction: .cpy, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.cpy(stepInfo: $0) }),
            InstructionInfo(opCode: 0xCD, instruction: .cmp, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xCE, instruction: .dec, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.dec(stepInfo: $0) }),
            InstructionInfo(opCode: 0xCF, instruction: .dcp, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xD0, instruction: .bne, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.bne(stepInfo: $0) }),
            InstructionInfo(opCode: 0xD1, instruction: .cmp, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xD2, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0xD3, instruction: .dcp, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xD4, instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0xD5, instruction: .cmp, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xD6, instruction: .dec, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.dec(stepInfo: $0) }),
            InstructionInfo(opCode: 0xD7, instruction: .dcp, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xD8, instruction: .cld, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.cld(stepInfo: $0) }),
            InstructionInfo(opCode: 0xD9, instruction: .cmp, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xDA, instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0xDB, instruction: .dcp, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xDC, instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0xDD, instruction: .cmp, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.cmp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xDE, instruction: .dec, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.dec(stepInfo: $0) }),
            InstructionInfo(opCode: 0xDF, instruction: .dcp, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.dcp(stepInfo: $0) }),
            InstructionInfo(opCode: 0xE0, instruction: .cpx, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.cpx(stepInfo: $0) }),
            InstructionInfo(opCode: 0xE1, instruction: .sbc, mode: .xIndexedIndirect, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xE2, instruction: .nop, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0xE3, instruction: .isc, mode: .xIndexedIndirect, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xE4, instruction: .cpx, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.cpx(stepInfo: $0) }),
            InstructionInfo(opCode: 0xE5, instruction: .sbc, mode: .zeropage,         cycles: 3, pageBoundaryCycles: 0, bytes: 2, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xE6, instruction: .inc, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 2, code: { self.inc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xE7, instruction: .isc, mode: .zeropage,         cycles: 5, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xE8, instruction: .inx, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.inx(stepInfo: $0) }),
            InstructionInfo(opCode: 0xE9, instruction: .sbc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 2, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xEA, instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0xEB, instruction: .sbc, mode: .immediate,        cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xEC, instruction: .cpx, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.cpx(stepInfo: $0) }),
            InstructionInfo(opCode: 0xED, instruction: .sbc, mode: .absolute,         cycles: 4, pageBoundaryCycles: 0, bytes: 3, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xEE, instruction: .inc, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 3, code: { self.inc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xEF, instruction: .isc, mode: .absolute,         cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xF0, instruction: .beq, mode: .relative,         cycles: 2, pageBoundaryCycles: 1, bytes: 2, code: { self.beq(stepInfo: $0) }),
            InstructionInfo(opCode: 0xF1, instruction: .sbc, mode: .indirectYIndexed, cycles: 5, pageBoundaryCycles: 1, bytes: 2, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xF2, instruction: .kil, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 0, code: { self.kil(stepInfo: $0) }),
            InstructionInfo(opCode: 0xF3, instruction: .isc, mode: .indirectYIndexed, cycles: 8, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xF4, instruction: .nop, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0xF5, instruction: .sbc, mode: .zeroPageXIndexed, cycles: 4, pageBoundaryCycles: 0, bytes: 2, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xF6, instruction: .inc, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 2, code: { self.inc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xF7, instruction: .isc, mode: .zeroPageXIndexed, cycles: 6, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xF8, instruction: .sed, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.sed(stepInfo: $0) }),
            InstructionInfo(opCode: 0xF9, instruction: .sbc, mode: .absoluteYIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xFA, instruction: .nop, mode: .implied,          cycles: 2, pageBoundaryCycles: 0, bytes: 1, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0xFB, instruction: .isc, mode: .absoluteYIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xFC, instruction: .nop, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.nop(stepInfo: $0) }),
            InstructionInfo(opCode: 0xFD, instruction: .sbc, mode: .absoluteXIndexed, cycles: 4, pageBoundaryCycles: 1, bytes: 3, code: { self.sbc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xFE, instruction: .inc, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 3, code: { self.inc(stepInfo: $0) }),
            InstructionInfo(opCode: 0xFF, instruction: .isc, mode: .absoluteXIndexed, cycles: 7, pageBoundaryCycles: 0, bytes: 0, code: { self.isc(stepInfo: $0) }),
        ]
    }()

    
    /// number of cycles
    var cycles: UInt64 = 0
    
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
    func flags() -> UInt8
    {
        let flagByte: UInt8 = UInt8.init(fromLittleEndianBitArray: [self.c, self.z, self.i, self.d, self.b, self.u, self.v, self.n])
        return flagByte
    }
    
    /// sets cpu flags from a UInt8 with bits arranged as c,z,i,d,b,u,v,n
    func set(flags aFlags: UInt8)
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
    func setZ(value aValue: UInt8)
    {
        self.z = (aValue == 0) ? true : false
    }
    
    /// sets the negative flag if the argument is negative (high bit is set)
    func setN(value aValue: UInt8)
    {
        self.n = (aValue & 0x80 != 0) ? true : false
    }

    ///  sets the zero flag and the negative flag
    func setZN(value aValue: UInt8)
    {
        self.setZ(value: aValue)
        self.setN(value: aValue)
    }
    
    /// compare two values and set zero, negative, and carry flags accordingly
    func compare(valueA aValueA: UInt8, valueB aValueB: UInt8)
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
            return self.mapper?.read(address: aAddress) ?? 0
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
            self.ppu?.writeRegister(address: aAddress, value: aValue)
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
            self.mapper?.write(address: aAddress, value: aValue)
        default:
            break
        }
    }
    
    /// checks whether two 16-bit addresses reside on different pages
    func pagesDiffer(address1 aAddress1: UInt16, address2 aAddress2: UInt16) -> Bool
    {
        return aAddress1 & 0xFF00 != aAddress2 & 0xFF00
    }
    
    /// reads two bytes using Read to return a double-word value
    func read16(address aAddress: UInt16) -> UInt16
    {
        let lo: UInt16 = UInt16(self.read(address: aAddress))
        let hi: UInt16 = UInt16(self.read(address: aAddress &+ 1))
        return (hi << 8) | lo
    }

    /// emulates a 6502 bug that caused the low byte to wrap without incrementing the high byte
    func read16bug(address aAddress: UInt16) -> UInt16
    {
        let a: UInt16 = aAddress
        let b: UInt16 = (a & 0xFF00) | UInt16((a % 256) &+ 1)
        let lo = self.read(address: a)
        let hi = self.read(address: b)
        return (UInt16(hi) << 8) | UInt16(lo)
    }
    
    // MARK: Stack
    
    /// pushes a byte onto the stack
    func push(value aValue: UInt8)
    {
        self.write(address: 0x100 | UInt16(self.sp), value: aValue)
        self.sp &-= 1
    }

    /// pops a byte from the stack
    func pull() -> UInt8
    {
        self.sp &+= 1
        return self.read(address: 0x100 | UInt16(self.sp))
    }

    /// pushes two bytes onto the stack
    func push16(value aValue: UInt16)
    {
        let hi: UInt8 = UInt8(aValue >> 8)
        let lo: UInt8 = UInt8(aValue & 0xFF)
        self.push(value: hi)
        self.push(value: lo)
    }

    // pull16 pops two bytes from the stack
    func pull16() -> UInt16
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
    func addBranchCycles(stepInfo aStepInfo: StepInfo)
    {
        self.cycles &+= 1
        if self.pagesDiffer(address1: aStepInfo.pc, address2: aStepInfo.address)
        {
            self.cycles &+= 1
        }
    }
    
    /// NMI - Non-Maskable Interrupt
    func nmi()
    {
        self.push16(value: self.pc)
        self.php(stepInfo: StepInfo(address: 0, pc: 0, mode: .implied))
        self.pc = self.read16(address: 0xFFFA)
        self.i = true
        self.cycles &+= 7
    }

    /// IRQ - IRQ Interrupt
    func irq()
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
    func adc(stepInfo aStepInfo: StepInfo)
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
    func and(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.a & self.read(address: aStepInfo.address)
        self.setZN(value: self.a)
    }

    /// ASL - Arithmetic Shift Left
    func asl(stepInfo aStepInfo: StepInfo)
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
    func bcc(stepInfo aStepInfo: StepInfo)
    {
        if self.c == false
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BCS - Branch if Carry Set
    func bcs(stepInfo aStepInfo: StepInfo)
    {
        if self.c == true
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BEQ - Branch if Equal
    func beq(stepInfo aStepInfo: StepInfo)
    {
        if self.z == true
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BIT - Bit Test
    func bit(stepInfo aStepInfo: StepInfo)
    {
        let value = self.read(address: aStepInfo.address)
        self.v = ((value >> 6) & 1) == 1
        self.setZ(value: value & self.a)
        self.setN(value: value)
    }

    /// BMI - Branch if Minus
    func bmi(stepInfo aStepInfo: StepInfo)
    {
        if self.n == true
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BNE - Branch if Not Equal
    func bne(stepInfo aStepInfo: StepInfo)
    {
        if self.z == false
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BPL - Branch if Positive
    func bpl(stepInfo aStepInfo: StepInfo)
    {
        if self.n == false
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }
    
    /// BRK - Force Interrupt
    func brk(stepInfo aStepInfo: StepInfo)
    {
        self.push16(value: self.pc)
        self.php(stepInfo: aStepInfo)
        self.sei(stepInfo: aStepInfo)
        self.pc = self.read16(address: 0xFFFE)
    }
    
    /// BVC - Branch if Overflow Clear
    func bvc(stepInfo aStepInfo: StepInfo)
    {
        if self.v == false
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// BVS - Branch if Overflow Set
    func bvs(stepInfo aStepInfo: StepInfo)
    {
        if self.v == true
        {
            self.pc = aStepInfo.address
            self.addBranchCycles(stepInfo: aStepInfo)
        }
    }

    /// CLC - Clear Carry Flag
    func clc(stepInfo aStepInfo: StepInfo)
    {
        self.c = false
    }

    /// CLD - Clear Decimal Mode
    func cld(stepInfo aStepInfo: StepInfo)
    {
        self.d = false
    }

    /// CLI - Clear Interrupt Disable
    func cli(stepInfo aStepInfo: StepInfo)
    {
        self.i = false
    }

    /// CLV - Clear Overflow Flag
    func clv(stepInfo aStepInfo: StepInfo)
    {
        self.v = false
    }

    /// CMP - Compare
    func cmp(stepInfo aStepInfo: StepInfo)
    {
        let value = self.read(address: aStepInfo.address)
        self.compare(valueA: self.a, valueB: value)
    }

    /// CPX - Compare X Register
    func cpx(stepInfo aStepInfo: StepInfo)
    {
        let value = self.read(address: aStepInfo.address)
        self.compare(valueA: self.x, valueB: value)
    }

    /// CPY - Compare Y Register
    func cpy(stepInfo aStepInfo: StepInfo)
    {
        let value = self.read(address: aStepInfo.address)
        self.compare(valueA: self.y, valueB: value)
    }

    /// DEC - Decrement Memory
    func dec(stepInfo aStepInfo: StepInfo)
    {
        let value = self.read(address: aStepInfo.address) &- 1
        self.write(address: aStepInfo.address, value: value)
        self.setZN(value: value)
    }

    /// DEX - Decrement X Register
    func dex(stepInfo aStepInfo: StepInfo)
    {
        self.x &-= 1 // decrement and wrap if needed
        self.setZN(value: self.x)
    }

    /// DEY - Decrement Y Register
    func dey(stepInfo aStepInfo: StepInfo)
    {
        self.y &-= 1 // decrement and wrap if needed
        self.setZN(value: self.y)
    }

    /// EOR - Exclusive OR
    func eor(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.a ^ self.read(address: aStepInfo.address)
        self.setZN(value: self.a)
    }

    /// INC - Increment Memory
    func inc(stepInfo aStepInfo: StepInfo)
    {
        let value: UInt8 = self.read(address: aStepInfo.address) &+ 1 // wrap if needed
        self.write(address: aStepInfo.address, value: value)
        self.setZN(value: value)
    }

    /// INX - Increment X Register
    func inx(stepInfo aStepInfo: StepInfo)
    {
        self.x &+= 1 // increment and wrap if needed
        self.setZN(value: self.x)
    }

    /// INY - Increment Y Register
    func iny(stepInfo aStepInfo: StepInfo)
    {
        
        self.y &+= 1 // increment and wrap if needed
        self.setZN(value: self.y)
    }

    /// JMP - Jump
    func jmp(stepInfo aStepInfo: StepInfo)
    {
        self.pc = aStepInfo.address
    }

    /// JSR - Jump to Subroutine
    func jsr(stepInfo aStepInfo: StepInfo)
    {
        self.push16(value: self.pc - 1)
        self.pc = aStepInfo.address
    }

    /// LDA - Load Accumulator
    func lda(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.read(address: aStepInfo.address)
        self.setZN(value: self.a)
    }

    /// LDX - Load X Register
    func ldx(stepInfo aStepInfo: StepInfo)
    {
        self.x = self.read(address: aStepInfo.address)
        self.setZN(value: self.x)
    }

    /// LDY - Load Y Register
    func ldy(stepInfo aStepInfo: StepInfo)
    {
        self.y = self.read(address: aStepInfo.address)
        self.setZN(value: self.y)
    }

    /// LSR - Logical Shift Right
    func lsr(stepInfo aStepInfo: StepInfo)
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
    func nop(stepInfo aStepInfo: StepInfo)
    {
        // do nothing
    }

    /// ORA - Logical Inclusive OR
    func ora(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.a | self.read(address: aStepInfo.address)
        self.setZN(value: self.a)
    }

    /// PHA - Push Accumulator
    func pha(stepInfo aStepInfo: StepInfo)
    {
        self.push(value: self.a)
    }

    /// PHP - Push Processor Status
    func php(stepInfo aStepInfo: StepInfo)
    {
        self.push(value: self.flags() | 0x10)
    }

    /// PLA - Pull Accumulator
    func pla(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.pull()
        self.setZN(value: self.a)
    }

    /// PLP - Pull Processor Status
    func plp(stepInfo aStepInfo: StepInfo)
    {
        self.set(flags: (self.pull() & 0xEF) | 0x20)
    }

    /// ROL - Rotate Left
    func rol(stepInfo aStepInfo: StepInfo)
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
    func ror(stepInfo aStepInfo: StepInfo)
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
    func rti(stepInfo aStepInfo: StepInfo)
    {
        self.set(flags: (self.pull() & 0xEF) | 0x20)
        self.pc = self.pull16()
    }

    /// RTS - Return from Subroutine
    func rts(stepInfo aStepInfo: StepInfo)
    {
        self.pc = self.pull16() &+ 1
    }

    /// SBC - Subtract with Carry
    func sbc(stepInfo aStepInfo: StepInfo)
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
    func sec(stepInfo aStepInfo: StepInfo)
    {
        self.c = true
    }

    /// SED - Set Decimal Flag
    func sed(stepInfo aStepInfo: StepInfo)
    {
        self.d = true
    }

    /// SEI - Set Interrupt Disable
    func sei(stepInfo aStepInfo: StepInfo)
    {
        self.i = true
    }

    /// STA - Store Accumulator
    func sta(stepInfo aStepInfo: StepInfo)
    {
        self.write(address: aStepInfo.address, value: self.a)
    }

    /// STX - Store X Register
    func stx(stepInfo aStepInfo: StepInfo)
    {
        self.write(address: aStepInfo.address, value: self.x)
    }

    /// STY - Store Y Register
    func sty(stepInfo aStepInfo: StepInfo)
    {
        self.write(address: aStepInfo.address, value: self.y)
    }

    /// TAX - Transfer Accumulator to X
    func tax(stepInfo aStepInfo: StepInfo)
    {
        self.x = self.a
        self.setZN(value: self.x)
    }

    /// TAY - Transfer Accumulator to Y
    func tay(stepInfo aStepInfo: StepInfo)
    {
        self.y = self.a
        self.setZN(value: self.y)
    }

    /// TSX - Transfer Stack Pointer to X
    func tsx(stepInfo aStepInfo: StepInfo)
    {
        self.x = self.sp
        self.setZN(value: self.x)
    }

    /// TXA - Transfer X to Accumulator
    func txa(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.x
        self.setZN(value: self.a)
    }

    /// TXS - Transfer X to Stack Pointer
    func txs(stepInfo aStepInfo: StepInfo)
    {
        self.sp = self.x
    }

    /// TYA - Transfer Y to Accumulator
    func tya(stepInfo aStepInfo: StepInfo)
    {
        self.a = self.y
        self.setZN(value: self.a)
    }
    
    // MARK: Illegal Instructions

    func ahx(stepInfo aStepInfo: StepInfo) {}
    func alr(stepInfo aStepInfo: StepInfo) {}
    func anc(stepInfo aStepInfo: StepInfo) {}
    func arr(stepInfo aStepInfo: StepInfo) {}
    func axs(stepInfo aStepInfo: StepInfo) {}
    func dcp(stepInfo aStepInfo: StepInfo) {}
    func isc(stepInfo aStepInfo: StepInfo) {}
    func kil(stepInfo aStepInfo: StepInfo) {}
    func las(stepInfo aStepInfo: StepInfo) {}
    func lax(stepInfo aStepInfo: StepInfo) {}
    func rla(stepInfo aStepInfo: StepInfo) {}
    func rra(stepInfo aStepInfo: StepInfo) {}
    func sax(stepInfo aStepInfo: StepInfo) {}
    func shx(stepInfo aStepInfo: StepInfo) {}
    func shy(stepInfo aStepInfo: StepInfo) {}
    func slo(stepInfo aStepInfo: StepInfo) {}
    func sre(stepInfo aStepInfo: StepInfo) {}
    func tas(stepInfo aStepInfo: StepInfo) {}
    func xaa(stepInfo aStepInfo: StepInfo) {}
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
