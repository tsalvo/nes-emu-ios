//
//  Data+MD5.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/8/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation
import CryptoKit

extension Data
{
    var md5: String
    {
        Insecure.MD5.hash(data: self).map({ String(format: "%02hhx", $0) }).joined()
    }
}
