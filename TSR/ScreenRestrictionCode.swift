//
//  ScreenRestrictionCode.swift
//  TSR
//
//  Created by Majed Hariri on 2/11/24.
//

import Foundation
import RealmSwift
import UIKit
import DeviceActivity
import ManagedSettings
import ManagedSettingsUI
import FamilyControls



/// The `ScreenRestriction` class is responsible for applying and clearing screen restrictions for a specific application.
class ScreenRestriction {
    static let shared = ScreenRestriction()
    
    /// This function applies the screen restrictions for the specified application.
    ///
    /// - Parameters:
    ///   - application: The `FamilyActivitySelection` object representing the application for which the restrictions should be applied.
    ///
    /// Usage Example:
    /// ```
    /// let application = FamilyActivitySelection(categoryTokens: ["Social Media"])
    /// ScreenRestriction.shared.applyRestrictions(application: application)
    /// ```
    func applyRestrictions() {
        print(#function, "Hello ")
        let record = UserDefaultsManager.shared.retrieveRecord()
        if record.string == Date().currentDateFormated() {
            if record.number > 0 {
                "".SendLocalNotification(DownloadNewFile: "\(#function)", restString: "The user did it Today")
                return
            }
        }
        "".SendLocalNotification(DownloadNewFile: "\(#function)", restString: "The user did not do it Today :\(record.number) - \(record.string)")
        let application = SelectedAppsForRestrictionDB.shared.selection
        let socialStore = ManagedSettingsStore(named: .social)
        socialStore.shield.applicationCategories = .specific(application.categoryTokens, except: Set())
        socialStore.shield.webDomainCategories = .specific(application.categoryTokens, except: Set())
    }
    
    /// This function clears the screen restrictions.
    ///
    /// Usage Example:
    /// ```
    /// ScreenRestriction.shared.clearRestrictions()
    /// ```
    func clearRestrictions() {
        print(#function)
        let socialStore = ManagedSettingsStore(named: .social)
        socialStore.clearAllSettings()
        "".SendLocalNotification(DownloadNewFile: "\(#function)", restString: "Restrictions Cleared")
    }
}


/// A singleton class that manages the selected apps for restriction.
//// Usage examples:
//let selectedAppsDB = SelectedAppsForRestrictionDB.shared
//
//// Retrieve the selected apps from the database
//if let savedSelection = selectedAppsDB.getSelectedAppsSavedINDB() {
//    print("Selected apps: \(savedSelection)")
//} else {
//    print("No selected apps found.")
//}
//
//// Save the selected apps in the database
//let selectedApps = FamilyActivitySelection()
//selectedAppsDB.saveSelectedAppsInDB(selection: selectedApps)
//
//// Clear the selected apps from the database
//selectedAppsDB.clearSelectedAppsInDB()
class SelectedAppsForRestrictionDB {
    static let shared = SelectedAppsForRestrictionDB()
    @Published var selection: FamilyActivitySelection = FamilyActivitySelection()
    private let userDefaultsKey = "ScreenTimeSelection"
    private let userDefaults = UserDefaults(suiteName: "group.me.TSR")
    
    private init() {
        if let savedSelection = getSelectedAppsSavedINDB() {
            selection = savedSelection
        }
    }
    
    /// Retrieves the selected apps saved in the database.
    /// - Returns: An optional `FamilyActivitySelection` object representing the selected apps, or `nil` if no selection is found.
    func getSelectedAppsSavedINDB() -> FamilyActivitySelection? {
        if let savedSelection = userDefaults?.object(forKey: userDefaultsKey) as? Data {
            let decoder = JSONDecoder()
            if let loadedSelection = try? decoder.decode(FamilyActivitySelection.self, from: savedSelection) {
                return loadedSelection
            }
        }
        return nil
    }
    
    /// Saves the selected apps in the database.
    /// - Parameter selection: The `FamilyActivitySelection` object representing the selected apps.
    func saveSelectedAppsInDB(selection: FamilyActivitySelection) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(selection) {
            userDefaults?.set(encoded, forKey: userDefaultsKey)
            print(#function, "Saved")
        }
    }
    
    /// Clears the selected apps from the database.
    func clearSelectedAppsInDB() {
        userDefaults?.removeObject(forKey: userDefaultsKey)
    }
}


/// A class responsible for scheduling and managing screen restrictions.
class SchedulingClass {
    static let shared = SchedulingClass()
    let deviceActivityCenter = DeviceActivityCenter()
    var haveTriedToReschedule: Bool = false
    
    /// Schedule screen restrictions during a specified time interval.
    ///
    /// - Parameters:
    ///   - startHour: The starting hour of the restriction (default is 9).
    ///   - startMinute: The starting minute of the restriction (default is 0).
    ///   - endHour: The ending hour of the restriction (default is 10).
    ///   - endMinute: The ending minute of the restriction (default is 0).
    ///
    /// - Note: The schedule is repeated daily.
    ///
    /// - Important: If the initial scheduling fails, the function will attempt to reschedule by increasing the start and end times by 1 minute.
    ///
    /// - Returns: None.
    ///
    /// - Example:
    ///   ```
    ///   SchedulingClass.shared.scheduleRestrictions(startHour: 9, startMinute: 0, endHour: 10, endMinute: 0)
    ///   ```
    ///
    ///   ```
    ///   SchedulingClass.shared.scheduleRestrictions(startHour: 8, startMinute: 30, endHour: 9, endMinute: 30)
    ///   ```
    func scheduleRestrictions(startHour: Int = 9, startMinute: Int = 0, endHour: Int = 10, endMinute: Int = 0) {
        // let's first clear all scheduled restrictions
        clearAllSecduledRestrictions()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [self] in
            let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: startHour, minute: startMinute), intervalEnd: DateComponents(hour: endHour, minute: endMinute), repeats: true)
            try? deviceActivityCenter.startMonitoring(.activity, during: schedule)
            let activity = deviceActivityCenter.schedule(for: .activity)
            if activity == nil{
                if !haveTriedToReschedule{
                    haveTriedToReschedule = true
                    if ProgressManager.shared.getProgress().count < 10 {
                        scheduleRestrictions(startHour: Date().convertToHour(), startMinute: Date().addTenMinutes(), endHour: endHour, endMinute: Date().addTenMinutes())
                    }else{
                        PredictExerciseTime.shared.predictBestExerciseTime()
                    }
                    
                    
                }else{
                    haveTriedToReschedule = false
                    print(#function, "Failed to schedule")
                }
            }else{
                print(#function, "Scheduled successfully \(startHour):\(startMinute)")
                print(#function, activity)
                NotifyManger.shared.show(message: "Scheduled successfully", type: .success)
            }
            
        }
    }
    
    /// Clear all scheduled screen restrictions.
    ///
    /// - Returns: None.
    ///
    /// - Example:
    ///   ```
    ///   SchedulingClass.shared.clearAllSecduledRestrictions()
    ///   ```
    func clearAllSecduledRestrictions() {
        let socialStore = ManagedSettingsStore(named: .social)
        socialStore.clearAllSettings()
        deviceActivityCenter.stopMonitoring([.activity])
        print(#function, "Cleared all scheduled restrictions")
    }
}



/**
 This class provides functionality to predict the best exercise time based on the frequency of exercise progress recorded.
 */
/**
 Singleton instance of `PredictExerciseTime`.
 */

/**
 Extracts the hour and minute from a given full date string.
 
 - Parameters:
 - fullDate: The full date string in the format "yyyy-MM-dd HH:mm:ss".
 
 - Returns: A tuple containing the extracted hour and minute as integers, or `nil` if the extraction fails.
 
 - Usage Example:
 ```
 if let time = extractHourAndMinute(fullDate: "2022-01-01 10:30:00") {
 print("Hour: \(time.0), Minute: \(time.1)")
 }
 ```
 */
fileprivate class PredictExerciseTime{
    static let shared = PredictExerciseTime()
    
    
    func predictBestExerciseTime(){
        var timeFrequency : [String: Int] = [:] // Key: "HH:mm", Value: Frequency
        let progress = ProgressManager.shared.getProgress()
        for item in progress {
            let timeKey = "\(item.hour)"
            timeFrequency[timeKey, default: 0] += 1
        }
        
        if let mostFrequentTime = timeFrequency.max(by: { $0.value < $1.value })?.key,
           let hour = Int(mostFrequentTime.split(separator: ":")[0]),
           let minute = Int(mostFrequentTime.split(separator: ":")[1]) {
            if let currentSchedulingTime = CurrentSchedulingTime.shared.getCurrentSchedulingTime() {
                if currentSchedulingTime.0 == hour && currentSchedulingTime.1 == minute {
                    print(#function,"The best exercise time is already scheduled")
                    return
                }
            }else {
                SchedulingClass.shared.clearAllSecduledRestrictions()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    SchedulingClass.shared.scheduleRestrictions(startHour: hour, startMinute: minute, endHour: hour + 2, endMinute: minute)
                }
            }
        }else{
            print(#function,"Failed to predict best exercise time due to missing data.")
        }
    }
    
    
    private func extractHourAndMinute(fullDate: String) -> (Int, Int)?{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = dateFormatter.date(from: fullDate) else {
            return nil
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour!, components.minute!)
    }
}


/// This file contains the implementation of the `CurrentSchedulingTime` class and its associated `CurrentSchedulingTimeDB` model.
///
/// The `CurrentSchedulingTime` class provides methods to save, retrieve, and delete the current scheduling time from a Realm database.
///
/// The `CurrentSchedulingTimeDB` model represents the schema for the current scheduling time in the Realm database.
class CurrentSchedulingTimeDB : Object{
    @Persisted var id = UUID().uuidString
    @Persisted var startHour : Int
    @Persisted var startMinute : Int
    
    convenience init(startHour: Int, startMinute: Int) {
        self.init()
        self.startHour = startHour
        self.startMinute = startMinute
    }
    
    override class func primaryKey() -> String? {
        return "id"
    }
}


/// The `CurrentSchedulingTime` class provides methods to save, retrieve, and delete the current scheduling time from a Realm database.
class CurrentSchedulingTime {
    static let shared = CurrentSchedulingTime()
    
    /// Saves the current scheduling time to the Realm database.
    ///
    /// - Parameters:
    ///   - startHour: The hour component of the scheduling time.
    ///   - startMinute: The minute component of the scheduling time.
    ///
    /// Usage Example:
    /// ```
    /// CurrentSchedulingTime.shared.saveCurrentSchedulingTime(startHour: 9, startMinute: 30)
    /// ```
    func saveCurrentSchedulingTime(startHour: Int, startMinute: Int){
        let realm = try! Realm()
        // let's delete the previous record if it exists
        deleteCurrentSchedulingTime()
        // then let's add the new record
        let newRecord = CurrentSchedulingTimeDB(startHour: startHour, startMinute: startMinute)
        try! realm.write {
            realm.add(newRecord)
        }
    }
    
    /// Retrieves the current scheduling time from the Realm database.
    ///
    /// - Returns: A tuple containing the hour and minute components of the current scheduling time, or `nil` if no scheduling time is found.
    ///
    /// Usage Example:
    /// ```
    /// if let schedulingTime = CurrentSchedulingTime.shared.getCurrentSchedulingTime() {
    ///     print("Current scheduling time: \(schedulingTime.0):\(schedulingTime.1)")
    /// } else {
    ///     print("No scheduling time found.")
    /// }
    /// ```
    func getCurrentSchedulingTime() -> (Int, Int)?{
        let realm = try! Realm()
        if let currentRecord = realm.objects(CurrentSchedulingTimeDB.self).first {
            return (currentRecord.startHour, currentRecord.startMinute)
        }
        return nil
    }
    
    /// Deletes the current scheduling time from the Realm database.
    ///
    /// Usage Example:
    /// ```
    /// CurrentSchedulingTime.shared.deleteCurrentSchedulingTime()
    /// ```
    func deleteCurrentSchedulingTime(){
        let realm = try! Realm()
        if let previousRecord = realm.objects(CurrentSchedulingTimeDB.self).first {
            try! realm.write {
                realm.delete(previousRecord)
            }
        }
    }
}


// Extension for ManagedSettingsStore.Name
extension ManagedSettingsStore.Name {
    static let social = ManagedSettingsStore.Name("social")
}

extension DeviceActivityName {
    static let activity = Self("activity")
    static let notification = Self("notification")
}


class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    
    func saveRecord(number: Int, string: String) {
        let defaults = UserDefaults.standard
        
        // Save new records. This will overwrite any existing value for these keys.
        defaults.set(number, forKey: "savedNumber")
        defaults.set(string, forKey: "savedString")
    }
    
    func retrieveRecord() -> (number: Int, string: String) {
        let defaults = UserDefaults.standard
        
        let number = defaults.integer(forKey: "savedNumber") // Returns 0 if not found
        let string = defaults.string(forKey: "savedString") ?? "" // Returns an empty string if not found
        
        return (number, string)
    }
    
    
    func saveDidSynced() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "didSynced")
    }

    func retrieveDidSynced() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: "didSynced")
    }
}
