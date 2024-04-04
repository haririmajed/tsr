//
//  NotificationTrigger.swift
//  TSR
//
//  Created by Majed Hariri on 2/13/24.
//

import Foundation
import UIKit
import RealmSwift

class NotificationTrigger {
    static let shared = NotificationTrigger()
    
    let motivationalTitles: [String] = [

        // ADD Titles

    ]
    
    let motivationalBody: [String] = [
        // ADD
    ]
    
    func newNotificationTimes(){
        print(#function, "Adios baby 👋🏻")
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1 ){ [self] in
            let notificationTime = RecommenderEngine.shared.predictNotificationTimes()
            for notTime in notificationTime {
                print(notTime)
                scheduleNotification(dateComponents: DateComponents(hour: notTime), title: getRandomTitle(), body: getRandomBody())
            }
        }
    }
    
    
    func getRandomTitle() -> String {
        let randomIndex = Int.random(in: 0..<motivationalTitles.count)
        return motivationalTitles[randomIndex]
    }
    
    func getRandomBody() -> String {
        let randomIndex = Int.random(in: 0..<motivationalBody.count)
        return motivationalBody[randomIndex]
    }
    
    
    func convertDateComponentsToString(dateComponents: DateComponents) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = Calendar.current.date(from: dateComponents) else { return nil }
        return dateFormatter.string(from: date)
    }
    
    func convertStringToDateComponents(dateString: String) -> DateComponents? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = dateFormatter.date(from: dateString) else { return nil }
        return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }
    
    func scheduleNotification(dateComponents: DateComponents, title : String, body : String, repeated : Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeated)
        let randomId = "".generateRandomUserID()
        let request = UNNotificationRequest(identifier: "majedoh.me.TSR_\(randomId)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("Error \(error.localizedDescription)")
            } else {
                print("Notification \(randomId) scheduled in \(dateComponents) hour.")
            }
        }
    }
    
    

    
    func getTheNumberOfPendingNotification(completion: @escaping (Int) -> Void ) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { request in
            completion(request.count)
        }
    }
}


extension String {
    func SendLocalNotification(DownloadNewFile : String, restString : String){
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (settings) in
            if settings.authorizationStatus == .authorized {
                let content = UNMutableNotificationContent()
                content.title = DownloadNewFile
                content.body = restString
                content.sound = UNNotificationSound.default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(identifier: "wa7sh.co.TSR\("".generateRandomUserID())", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        })
        
    }
}
