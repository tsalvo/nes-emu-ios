//
//  Settings.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/20/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

protocol SettingsEnum
{
    var friendlyName: String { get }
    var storedValue: Any { get }
}

class Settings
{
    // MARK: - UserDefaults Keys
    static let sampleRateKey: String = "sampleRateKey"
    static let audioFiltersEnabledKey: String = "audioFiltersEnabledKey"
    static let audioSessionNotifyOthersOnDeactivationKey: String = "audioSessionNotifyOthersOnDeactivationKey"
    
    // MARK: - Default Values
    static let defaultSampleRate: SampleRate = SampleRate._22050Hz
    static let defaultAudioSessionNotifyOthersOnDeactivation = true
    static let defaultAudioFiltersEnabled: Bool = true

    class func registerDefaultsIfNeeded()
    {
        UserDefaults.standard.register(defaults: [
            Settings.sampleRateKey: Settings.defaultSampleRate.rawValue,
            Settings.audioFiltersEnabledKey: Settings.defaultAudioFiltersEnabled,
            Settings.audioSessionNotifyOthersOnDeactivationKey: Settings.defaultAudioSessionNotifyOthersOnDeactivation,
        ])
    }
    
    enum CellType
    {
        case Toggle, About, Info, Segmented
    }
    
    struct Cell
    {
        var key: String?
        var title: String?
        var description: String?
        var metadata: Any?
        var type: Settings.CellType = .Toggle
    }
    
    struct HelpEntry
    {
        var header: String
        var description: String
        var iconNames: [String]?
    }
    
    struct Section
    {
        var sectionName: String?
        var cells: [Settings.Cell]
    }
}
