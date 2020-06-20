//
//  Settings.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/20/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

class Settings
{
    static let sampleRateKey: String = "sampleRateKey"
    static let audioSessionNotifyOthersOnDeactivationKey: String = "audioSessionNotifyOthersOnDeactivationKey"
    
    class func registerDefaultsIfNeeded()
    {
        UserDefaults.standard.register(defaults: [
            Settings.sampleRateKey: SampleRate._22050Hz.rawValue,
            Settings.audioSessionNotifyOthersOnDeactivationKey: true,
        ])
    }
}
