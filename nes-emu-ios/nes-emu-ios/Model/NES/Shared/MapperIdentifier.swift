//
//  MapperIdentifier.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/14/20.
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
    _008 = 8,
    MMC2 = 9,
    MMC4 = 10,
    ColorDreams = 11,
    _012 = 12,
    CPROM = 13,
    _014 = 14,
    Multi100In1ContraFunction16 = 15,
    BandaiEPROM = 16,
    _017 = 17,
    JalecoSS8806 = 18,
    Namco163 = 19,
    _020 = 20,
    VRC4a_VRC4c = 21,
    VRC2a = 22,
    VRC2b_VRC4e = 23,
    VRC6a = 24,
    VRC4b_VRC4d = 25,
    VRC6b = 26,
    _027 = 27,
    Action_53 = 28,
    _029 = 29,
    UNRO_512 = 30,
    _031 = 31,
    Ire_G101 = 32,
    TC0190_TC0350 = 33,
    BNRO_NINA001 = 34,
    _035 = 35,
    TXC_01_22000_400 = 36,
    _037 = 37,
    UNL_PCI556 = 38,
    _039 = 39,
    NTDEC_2722 = 40,
    _041 = 41,
    _042 = 42,
    _043 = 43,
    _044 = 44,
    _045 = 45,
    _046 = 46,
    _047 = 47,
    _048 = 48,
    _049 = 49,
    _050 = 50,
    _051 = 51,
    _052 = 52,
    _053 = 53,
    _054 = 54,
    _055 = 55,
    _056 = 56,
    _057 = 57,
    _058 = 58,
    _059 = 59,
    _060 = 60,
    _061 = 61,
    _062 = 62,
    _063 = 63,
    RAMBO1 = 64,
    Ire_H3001 = 65,
    GxROM = 66,
    _067 = 67,
    _068 = 68,
    Sunsoft_5 = 69,
    _070 = 70,
    Camerica = 71,
    _072 = 72,
    _073 = 73,
    _074 = 74,
    _075 = 75,
    _076 = 76,
    _077 = 77,
    _078 = 78,
    _079 = 79,
    _080 = 80,
    _081 = 81,
    Taito_X117 = 82,
    _083 = 83,
    _084 = 84,
    _085 = 85,
    _086 = 86,
    _087 = 87,
    Namco_118 = 88,
    _089 = 89,
    _090 = 90,
    _091 = 91,
    _092 = 92,
    _093 = 93,
    _094 = 94,
    Namco_1xx = 95,
    _096 = 96,
    Ire_74161_32 = 97,
    _098 = 98,
    _099 = 99,
    _100 = 100,
    _101 = 101,
    _102 = 102,
    _103 = 103,
    _104 = 104,
    _105 = 105,
    _106 = 106,
    _107 = 107,
    _108 = 108,
    _109 = 109,
    _110 = 110,
    _111 = 111,
    _112 = 112,
    _113 = 113,
    _114 = 114,
    _115 = 115,
    _116 = 116,
    _117 = 117,
    _118 = 118,
    TQROM = 119,
    _120 = 120,
    _121 = 121,
    _122 = 122,
    _123 = 123,
    _124 = 124,
    _125 = 125,
    _126 = 126,
    _127 = 127,
    _128 = 128,
    _129 = 129,
    _130 = 130,
    _131 = 131,
    _132 = 132,
    _133 = 133,
    _134 = 134,
    _135 = 135,
    _136 = 136,
    _137 = 137,
    _138 = 138,
    _139 = 139,
    _140 = 140,
    _141 = 141,
    _142 = 142,
    _143 = 143,
    _144 = 144,
    _145 = 145,
    _146 = 146,
    _147 = 147,
    _148 = 148,
    _149 = 149
    
    var isSupported: Bool
    {
        switch self
        {
        case .NROM,
             .UxROM,
             .MMC1,
             .CNROM,
             .MMC3,
             .AxROM,
             .MMC2,
             .ColorDreams,
             .GxROM,
             .MMC5:
            return true
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
