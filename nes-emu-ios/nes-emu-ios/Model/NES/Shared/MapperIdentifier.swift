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
    M_008 = 8,
    MMC2 = 9,
    MMC4 = 10,
    ColorDreams = 11,
    M_012 = 12,
    CPROM = 13,
    M_014 = 14,
    Multi100In1ContraFunction16 = 15,
    BandaiEPROM = 16,
    M_017 = 17,
    JalecoSS8806 = 18,
    Namco163 = 19,
    M_020 = 20,
    VRC4a_VRC4c = 21,
    VRC2a = 22,
    VRC2b_VRC4e = 23,
    VRC6a = 24,
    VRC4b_VRC4d = 25,
    VRC6b = 26,
    M_027 = 27,
    Action_53 = 28,
    M_029 = 29,
    UNROM_512 = 30,
    M_031 = 31,
    M_032 = 32,
    TC0190_TC0350 = 33,
    BNROM_NINA001 = 34,
    M_035 = 35,
    M_036 = 36,
    M_037 = 37,
    M_038 = 38,
    M_039 = 39,
    M_040 = 40,
    M_041 = 41,
    M_042 = 42,
    M_043 = 43,
    M_044 = 44,
    M_045 = 45,
    M_046 = 46,
    M_047 = 47,
    M_048 = 48,
    M_049 = 49,
    M_050 = 50,
    M_051 = 51,
    M_052 = 52,
    M_053 = 53,
    M_054 = 54,
    M_055 = 55,
    M_056 = 56,
    M_057 = 57,
    M_058 = 58,
    M_059 = 59,
    M_060 = 60,
    M_061 = 61,
    M_062 = 62,
    M_063 = 63,
    RAMBO1 = 64,
    M_065 = 65,
    _74161_32 = 66,
    M_067 = 67,
    M_068 = 68,
    Sunsoft_5 = 69,
    M_070 = 70,
    Camerica = 71,
    M_072 = 72,
    M_073 = 73,
    M_074 = 74,
    M_075 = 75,
    M_076 = 76,
    M_077 = 77,
    M_078 = 78,
    M_079 = 79,
    M_080 = 80,
    M_081 = 81,
    M_082 = 82,
    M_083 = 83,
    M_084 = 84,
    M_085 = 85,
    M_086 = 86,
    M_087 = 87,
    M_088 = 88,
    M_089 = 89,
    M_090 = 90,
    M_091 = 91,
    M_092 = 92,
    M_093 = 93,
    M_094 = 94,
    M_095 = 95,
    M_096 = 96,
    M_097 = 97,
    M_098 = 98,
    M_099 = 99,
    M_100 = 100
    
    var isSupported: Bool
    {
        switch self
        {
        case .NROM, .UxROM, .MMC1, .CNROM, .MMC3, .AxROM, .MMC2: return true
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
