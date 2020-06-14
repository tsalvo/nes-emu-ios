//
//  MapperIdentifier.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/14/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

enum MapperIdentifier: UInt8
{
    // see https://wiki.nesdev.com/w/index.php/List_of_mappers
    case NROM = 0,
    MMC1 = 1,
    UxROM = 2,
    CNROM = 3,
    MMC3 = 4,
    MMC5 = 5,
    FFE_F4XXX = 6,
    AxROM = 7,
    MAPPER_008 = 8,
    MMC2 = 9,
    MMC4 = 10,
    ColorDreams = 11,
    MAPPER_012 = 12,
    CPROM = 13,
    MAPPER_014 = 14,
    Multi100In1ContraFunction16 = 15,
    BandaiEPROM = 16,
    MAPPER_017 = 17,
    JalecoSS8806 = 18,
    Namco163 = 19,
    MAPPER_020 = 20,
    VRC4a_VRC4c = 21,
    VRC2a = 22,
    VRC2b_VRC4e = 23,
    VRC6a = 24,
    VRC4b_VRC4d = 25,
    VRC6b = 26,
    MAPPER_027 = 27,
    Action_53 = 28,
    MAPPER_029 = 29,
    UNROM_512 = 30,
    MAPPER_031 = 31,
    MAPPER_032 = 32,
    TC0190_TC0350 = 33,
    BNROM_NINA001 = 34,
    MAPPER_035 = 35,
    MAPPER_036 = 36,
    MAPPER_037 = 37,
    MAPPER_038 = 38,
    MAPPER_039 = 39,
    MAPPER_040 = 40,
    MAPPER_041 = 41,
    MAPPER_042 = 42,
    MAPPER_043 = 43,
    MAPPER_044 = 44,
    MAPPER_045 = 45,
    MAPPER_046 = 46,
    MAPPER_047 = 47,
    MAPPER_048 = 48,
    MAPPER_049 = 49,
    MAPPER_050 = 50,
    MAPPER_051 = 51,
    MAPPER_052 = 52,
    MAPPER_053 = 53,
    MAPPER_054 = 54,
    MAPPER_055 = 55,
    MAPPER_056 = 56,
    MAPPER_057 = 57,
    MAPPER_058 = 58,
    MAPPER_059 = 59,
    MAPPER_060 = 60,
    MAPPER_061 = 61,
    MAPPER_062 = 62,
    MAPPER_063 = 63,
    RAMBO1 = 64,
    MAPPER_065 = 65,
    _74161_32 = 66,
    MAPPER_067 = 67,
    MAPPER_068 = 68,
    Sunsoft_5 = 69,
    MAPPER_070 = 70,
    Camerica = 71,
    MAPPER_072 = 72,
    MAPPER_073 = 73,
    MAPPER_074 = 74,
    MAPPER_075 = 75,
    MAPPER_076 = 76,
    MAPPER_077 = 77,
    MAPPER_078 = 78,
    MAPPER_079 = 79,
    MAPPER_080 = 80
    
    var isSupported: Bool
    {
        switch self
        {
        case .NROM, .MMC1: return true
        default: return false
        }
    }
    
    var hasExpansionAudio: Bool
    {
        switch self
        {
        case .Namco163, .VRC6a, .VRC6b, .MMC5: return true
        default: return false
        }
    }
}
