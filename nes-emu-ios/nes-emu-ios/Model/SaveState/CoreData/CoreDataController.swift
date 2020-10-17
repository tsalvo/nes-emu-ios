//
//  CoreDataController.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit
import CoreData

struct CoreDataController
{
    static let maximumAutoSavesPerGame: Int = 3
    static let maximumManualSavesPerGame: Int = 13
    static private let cpuStateEntityName: String = "CPUState_CD"
    static private let ppuStateEntityName: String = "PPUState_CD"
    static private let apuStateEntityName: String = "APUState_CD"
    static private let mapperStateEntityName: String = "MapperState_CD"
    static private let consoleStateEntityName: String = "ConsoleState_CD"
    static private let pulseStateEntityName: String = "PulseState_CD"
    static private let triangleStateEntityName: String = "TriangleState_CD"
    static private let noiseStateEntityName: String = "NoiseState_CD"
    static private let dmcStateEntityName: String = "DMCState_CD"
    
    static func removeAllConsoleStates() throws
    {
        guard let managedContext = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
            else
        {
            return
        }
        
        let fetchRequest_Console = NSFetchRequest<NSManagedObject>(entityName: CoreDataController.consoleStateEntityName)
        
        do
        {
            let consoleStates = try managedContext.fetch(fetchRequest_Console)
            for c in consoleStates
            {
                managedContext.delete(c)
            }
            try managedContext.save()
        }
        catch
        {
            throw error
        }
    }
    
    static func removeConsoleState(forMD5 aMD5: String, date aDate: Date) throws
    {
        guard let managedContext = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
            else
        {
            return
        }
        
        let fetchRequest_Console = NSFetchRequest<NSManagedObject>(entityName: CoreDataController.consoleStateEntityName)
        fetchRequest_Console.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "md5 == %@", aMD5), NSPredicate(format: "date == %@", aDate as NSDate)])
        
        do
        {
            let consoleStates = try managedContext.fetch(fetchRequest_Console)
            for c in consoleStates
            {
                managedContext.delete(c)
            }
            try managedContext.save()
        }
        catch
        {
            throw error
        }
    }
    
    /// Returns the most recent ConsoleState for a given ROM's MD5 hash
    static func mostRecentConsoleState(forMD5 aMD5: String) -> ConsoleState?
    {
        guard let consoleStates: [ConsoleState] = try? CoreDataController.consoleStates(forMD5: aMD5) else { return nil }
        
        return consoleStates.sorted(by: { $0.date < $1.date }).last
    }
    
    /// Returns an array of console states for a given ROM's MD5 hash, sorted by date (most recent first)
    static func consoleStates(forMD5 aMD5: String) throws -> [ConsoleState]?
    {
        do
        {
            let consoleStates: [ConsoleState]? = try CoreDataController.consoleStateManagedObjects(forMD5: aMD5)?.compactMap({ $0.consoleStateStruct })
            return consoleStates?.sorted(by: { $0.date > $1.date })
        }
        catch
        {
            throw error
        }
    }
    
    static func save(consoleState aConsoleState: ConsoleState) throws
    {
        guard let managedContext = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext,
            let cpuStateEntity = NSEntityDescription.entity(forEntityName: CoreDataController.cpuStateEntityName, in: managedContext),
            let mapperStateEntity = NSEntityDescription.entity(forEntityName: CoreDataController.mapperStateEntityName, in: managedContext),
            let apuStateEntity = NSEntityDescription.entity(forEntityName: CoreDataController.apuStateEntityName, in: managedContext),
            let ppuStateEntity = NSEntityDescription.entity(forEntityName: CoreDataController.ppuStateEntityName, in: managedContext),
            let consoleStateEntity = NSEntityDescription.entity(forEntityName: CoreDataController.consoleStateEntityName, in: managedContext),
            let pulseEntity = NSEntityDescription.entity(forEntityName: CoreDataController.pulseStateEntityName, in: managedContext),
            let triangleEntity = NSEntityDescription.entity(forEntityName: CoreDataController.triangleStateEntityName, in: managedContext),
            let noiseEntity = NSEntityDescription.entity(forEntityName: CoreDataController.noiseStateEntityName, in: managedContext),
            let dmcEntity = NSEntityDescription.entity(forEntityName: CoreDataController.dmcStateEntityName, in: managedContext)
        else
        {
            return
        }

        let cpuState = NSManagedObject(entity: cpuStateEntity, insertInto: managedContext)
        cpuState.cpuStateStruct = aConsoleState.cpuState
        
        let mapperState = NSManagedObject(entity: mapperStateEntity, insertInto: managedContext)
        mapperState.mapperStateStruct = aConsoleState.mapperState
        
        let ppuState = NSManagedObject(entity: ppuStateEntity, insertInto: managedContext)
        ppuState.ppuStateStruct = aConsoleState.ppuState
        
        let pulse1 = NSManagedObject(entity: pulseEntity, insertInto: managedContext)
        pulse1.pulseStateStruct = aConsoleState.apuState.pulse1
        
        let pulse2 = NSManagedObject(entity: pulseEntity, insertInto: managedContext)
        pulse2.pulseStateStruct = aConsoleState.apuState.pulse2
        
        let triangle = NSManagedObject(entity: triangleEntity, insertInto: managedContext)
        triangle.triangleStateStruct = aConsoleState.apuState.triangle
        
        let noise = NSManagedObject(entity: noiseEntity, insertInto: managedContext)
        noise.noiseStateStruct = aConsoleState.apuState.noise
        
        let dmc = NSManagedObject(entity: dmcEntity, insertInto: managedContext)
        dmc.dmcStateStruct = aConsoleState.apuState.dmc
        
        let apuState = NSManagedObject(entity: apuStateEntity, insertInto: managedContext)
        apuState.apuStateStruct = aConsoleState.apuState
        apuState.setValuesForKeys(["pulseStates": [pulse1, pulse2], "triangleState": triangle, "noiseState": noise, "dmcState": dmc])
        
        let consoleState = NSManagedObject(entity: consoleStateEntity, insertInto: managedContext)
        consoleState.setValuesForKeys(["isAutoSave": aConsoleState.isAutoSave, "date": Date(), "md5": aConsoleState.md5, "cpuState": cpuState, "mapperState": mapperState, "ppuState": ppuState, "apuState": apuState])

        do
        {
            try managedContext.save()
            try CoreDataController.pruneConsoleStates(forMD5: aConsoleState.md5)
        }
        catch
        {
            throw error
        }
    }
    
    // MARK: - Private Functions
    
    static private func pruneConsoleStates(forMD5 aMD5: String) throws
    {
        guard let managedContext = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext,
            let consoleStates = try? CoreDataController.consoleStateManagedObjects(forMD5: aMD5)
        else
        {
            return
        }
        
        // descending order
        var sortedAutoStates = consoleStates.sorted(by: { ($0.value(forKeyPath: "date") as? Date ?? Date.distantPast ) > ($1.value(forKeyPath: "date") as? Date ?? Date.distantPast) }).filter({ $0.value(forKeyPath: "isAutoSave") as? Bool ?? false })
        
        var sortedManualStates = consoleStates.sorted(by: { ($0.value(forKeyPath: "date") as? Date ?? Date.distantPast ) > ($1.value(forKeyPath: "date") as? Date ?? Date.distantPast) }).filter({ !($0.value(forKeyPath: "isAutoSave") as? Bool ?? false) })
        
        while sortedAutoStates.count > CoreDataController.maximumAutoSavesPerGame
        {
            if let last = sortedAutoStates.popLast()
            {
                managedContext.delete(last)
            }
        }
        
        while sortedManualStates.count > CoreDataController.maximumManualSavesPerGame
        {
            if let last = sortedManualStates.popLast()
            {
                managedContext.delete(last)
            }
        }
        
        do
        {
            try managedContext.save()
        }
        catch
        {
            throw error
        }
    }
    
    static private func consoleStateManagedObjects(forMD5 aMD5: String) throws -> [NSManagedObject]?
    {
        guard let managedContext = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
            else
        {
            return nil
        }

        let fetchRequest_Console = NSFetchRequest<NSManagedObject>(entityName: CoreDataController.consoleStateEntityName)
        fetchRequest_Console.predicate =  NSPredicate(format: "md5 == %@", aMD5)

        do
        {
            let consoleStates = try managedContext.fetch(fetchRequest_Console)
            return consoleStates
        }
        catch
        {
            throw error
        }
    }
}
