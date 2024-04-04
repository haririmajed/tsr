//
//  RewardManager.swift
//  TSR
//
//  Created by Majed Hariri on 2/15/24.
//

import Foundation
import UIKit
import RealmSwift
import CreateML

class RewardManager {
    static let shared = RewardManager() // Singleton instance
    private var basePoints: Double = 10.0 // Base points for the first repetition
    
    // New function to calculate reward points for the current repetition number
    func calculateRewardForCurrentRepetition(currentSessionRepetitions: Int) -> Double {
        let progress = ProgressManager.shared.getProgress()
        var totalRepetitions = 0
        for day in progress {
            totalRepetitions += day.repetitions // Calculate total historical repetitions
        }
        
        // Determine user level based on total historical repetitions
        let userLevel: UserLevel = determineUserLevel(totalRepetitions: totalRepetitions)
        determiningBasePointsBasedOnUserLevel(userLevel: userLevel)
        
        // Calculate the difficulty factor based on current session repetitions and user level
        let difficultyFactor = calculateDifficultyFactor(repetitions: currentSessionRepetitions, userLevel: userLevel)
        
        // Calculate the maximum points per repetition for the user's level
        let maxPointsPerRep = calculateMaxPointsPerRep(userLevel: userLevel)
        
        // Calculate reward points for the current repetition
        var rewardPoints = basePoints + maxPointsPerRep * difficultyFactor
        
        // Ensure rewardPoints is never less than basePoints
        rewardPoints = max(rewardPoints, basePoints)
        rewardPoints = roundRewardPoints(rewardPoints)
        return rewardPoints
    }
    
    // Helper function to determine user's level
    private
    func determineUserLevel(totalRepetitions: Int) -> UserLevel {
        switch totalRepetitions {
        case 0..<50:
            return .beginner
        case 50..<200:
            return .intermediate
        default:
            return .experienced
        }
    }
    
    // Helper function to calculate difficulty factor based on user level and repetitions
    private
    func calculateDifficultyFactor(repetitions: Int, userLevel: UserLevel) -> Double {
        let valueReward: Double = userLevel.valueReward
        let difficultyFactor = max(min(Double(repetitions) * valueReward, 0.9), 0.1)
        return difficultyFactor
    }
    
    // Function to calculate the maximum points per repetition based on user level
    private
    func calculateMaxPointsPerRep(userLevel: UserLevel) -> Double {
        switch userLevel {
        case .beginner:
            return 20.0 // Maximum ceiling for beginners
        case .intermediate:
            return 17.5 // Adjust as necessary for intermediate users
        case .experienced:
            return 15.0 // Maximum ceiling for experienced users
        }
    }
    
    private
    func determiningBasePointsBasedOnUserLevel(userLevel: UserLevel) {
        switch userLevel {
        case .beginner:
            basePoints = 20.0
        case .intermediate:
            basePoints = 15.0
        case .experienced:
            basePoints = 10.0
        }
    }
    
    private
    func roundRewardPoints(_ points: Double) -> Double {
        let roundedUpPoints = ceil(points) // Round up to the nearest whole number
        let remainder = Int(roundedUpPoints).remainderReportingOverflow(dividingBy: 5).partialValue // Find the remainder when divided by 5
        if remainder == 0 {
            return roundedUpPoints // If already a multiple of 5, return as is
        } else {
            return roundedUpPoints + Double(5 - remainder) // Otherwise, add the difference to get to the next multiple of 5
        }
    }
}


// Enumeration for user levels with associated value rewards
enum UserLevel {
    case beginner, intermediate, experienced
    
    var valueReward: Double {
        switch self {
        case .beginner:
            return 0.2 // Increase this value to motivate beginners to do more
        case .intermediate:
            return 0.4 // Adjust based on average performance
        case .experienced:
            return 0.001 // Experienced users need less motivation to increase
        }
    }
}


struct ChallengeStructure : Identifiable, Hashable {
    var id : String
    var targetRepetitions: Int
    var isCompleted: Bool
    var date: Date
    
    init (id: String = UUID().uuidString, targetRepetitions: Int, isCompleted: Bool, date: Date) {
        self.id = id
        self.targetRepetitions = targetRepetitions
        self.isCompleted = isCompleted
        self.date = date
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class DailyChallengeDB : Object {
    @Persisted var id = UUID().uuidString
    @Persisted var targetRepetitions: Int
    @Persisted var isCompleted: Bool
    @Persisted var date: Date
    
    convenience init(targetRepetitions: Int, isCompleted: Bool, date: Date) {
        self.init()
        self.targetRepetitions = targetRepetitions
        self.isCompleted = isCompleted
        self.date = date
    }
    
    override class func primaryKey() -> String? {
        return "id"
    }
}

class DailyChallengeManager {
    static let shared = DailyChallengeManager()
    private var targetRepetitions: Int = 0
    
    init() {
        print(#function ,"DailyChallengeManager initialized")
    }
    
    // Function to set the daily challenge target
    private
    func setDailyChallenge(completion: @escaping (Int) -> Void) {
        let progress = ProgressManager.shared.getProgress()
        let totalRepetitions = progress.reduce(0) { $0 + $1.repetitions }
        let totalPoints = progress.reduce(0) {$0 + $1.points}
        let daysCount = progress.count + 1
        let minimumJumps = 20
        
        // Set a default average if no progress data is available
        let averageRepetitions = daysCount > 0 ? totalRepetitions / daysCount : minimumJumps
        let averagePoints = daysCount > 0 ? totalPoints / daysCount : 100
        
        var predictedRepNumber = max(averageRepetitions, minimumJumps)
        
        if daysCount > 1 {
            RecommenderEngine.shared.trainModel(type: .repetitions) { model in
                guard let regressor: MLLinearRegressor = model else {
                    print("Failed to train the model")
                    
                    
                    self.targetRepetitions = Int(Double(predictedRepNumber) * 1.2) // Increase by 20% as a challenge
                    print("Final number \(self.targetRepetitions) ")
                    self.createNewChallenge(predictedRepNumber: self.targetRepetitions)
                    completion(self.targetRepetitions)
                    
                    return
                }
                
                let progressModel = ProgressModel(userID: OnBoardingManager.shared.getUserID(),
                                                  date: Date().currentDateFormated(),
                                                  hour: Date().convertToHour(),
                                                  repetitions: averageRepetitions,
                                                  points: averagePoints)
                
                let prediction: Double = RecommenderEngine.shared.predict(forProgressModel: progressModel,
                                                                          usingRegressor: regressor,
                                                                          type: .repetitions).rounded(.up)
                
                print("Progress Model: \(progressModel)")
                print(#function, "HERE averageRepetitions: \(averageRepetitions)")
                print(#function, "HERE prediction: \(prediction)")
                print(#function, "HERE predictedRepNumber: \(predictedRepNumber)")
                
                if prediction > 0 {
                    let maxNumber = Int(prediction)
                    predictedRepNumber = max(minimumJumps, min(averageRepetitions, maxNumber))
                }
                DispatchQueue.main.async {
                    // Set a challenging yet attainable target
                    self.targetRepetitions = Int(Double(predictedRepNumber) * 1.2) // Increase by 20% as a challenge
                    print("Final number \(self.targetRepetitions) ")
                    self.createNewChallenge(predictedRepNumber: self.targetRepetitions)
                    completion(self.targetRepetitions)
                }
            }
        } else {
            DispatchQueue.main.async {
                print("No progress data available. Setting default challenge.")
                print(#function, "HERE averageRepetitions: \(averageRepetitions)")
                print(#function, "HERE predictedRepNumber: \(predictedRepNumber)")
                // Set a challenging yet attainable target
                self.targetRepetitions = Int(Double(predictedRepNumber) * 1.2) // Increase by 20% as a challenge
                print("Final number \(self.targetRepetitions) ")
                self.createNewChallenge(predictedRepNumber: self.targetRepetitions)
                completion(self.targetRepetitions)
            }
        }
    }
    
    private
    func createNewChallenge(predictedRepNumber: Int) {
        DispatchQueue.main.async { [self] in
            //create a new daily challenge
            let newChallenge = ChallengeStructure(targetRepetitions: targetRepetitions, isCompleted: false, date: Date())
            
            // let's delete the old challenge
            deleteOldChallenges()
            // save the new challenge
            DispatchQueue.main.asyncAfter(deadline: .now() + 1){
                self.saveChallenge(challenge: newChallenge)
            }
        }
    }
    
    
    func updateCompletedChallenge(){
        let realm = try! Realm()
        let challenges = realm.objects(DailyChallengeDB.self)
        if let challenge = challenges.first {
            try! realm.write {
                challenge.isCompleted = true
            }
        }
    }
    
    func getDailyChallengeRepetitions(completion: @escaping (ChallengeStructure) -> Void){
        // let realm = try! Realm()
        // let challenges = realm.objects(DailyChallengeDB.self)
        // if let challenge = challenges.first {
        //     return challenge.targetRepetitions
        // }
        // return 0
        // Before returning the targetRepetitions, let's do the following:
        // 1. Check if the current date is the same as the date of the challenge
        // 2. If the date is different, set a new daily challenge
        // 3. If the date is the same, return the targetRepetitions
        
        // also let's add a check to see if the challenge is completed for the same day and if so return 0
        if isDailyChallengeCompleted() {
            completion(ChallengeStructure(targetRepetitions: 0, isCompleted: true, date: Date()))
            return
        }
        
        let realm = try! Realm()
        let challenges = realm.objects(DailyChallengeDB.self).sorted(byKeyPath: "date", ascending: false)
        print(#function, "HERE challenges : \(challenges.count)")
        if let challenge = challenges.first {
            let date = challenge.date
            let currentDate = Date()
            let calendar = Calendar.current
            let currentDay = calendar.component(.day, from: currentDate)
            let challengeDay = calendar.component(.day, from: date)
            if currentDay != challengeDay {
                DispatchQueue.main.async {
                    self.setDailyChallenge { targetRep in
                        completion(ChallengeStructure(targetRepetitions: targetRep, isCompleted: false, date: Date()))
                    }
                }
                
            }else{
                completion(ChallengeStructure(id: challenge.id, targetRepetitions: challenge.targetRepetitions, isCompleted: challenge.isCompleted, date: challenge.date))
            }
        }else{
            setDailyChallenge {targetRep in
                completion(ChallengeStructure(targetRepetitions: targetRep, isCompleted: false, date: Date()))
            }
        }
    }
    
    private
    func isDailyChallengeCompleted() -> Bool {
        let realm = try! Realm()
        let challenges = realm.objects(DailyChallengeDB.self)
        if let challenge = challenges.first {
            let date = challenge.date
            let currentDate = Date()
            let calendar = Calendar.current
            let currentDay = calendar.component(.day, from: currentDate)
            let challengeDay = calendar.component(.day, from: date)
            if currentDay == challengeDay {
                return challenge.isCompleted
            }else {
                deleteOldChallenges()
                return false
            }
        }
        return false
    }
    
    private
    func deleteOldChallenges(){
        DispatchQueue.main.async {
            let realm = try! Realm()
            let challenges = realm.objects(DailyChallengeDB.self)
            try! realm.write {
                realm.delete(challenges)
            }
        }
    }
    
    private
    func saveChallenge(challenge: ChallengeStructure){
        DispatchQueue.main.async {
            let realm = try! Realm()
            let challengeDB = DailyChallengeDB(targetRepetitions: challenge.targetRepetitions, isCompleted: challenge.isCompleted, date: challenge.date)
            try! realm.write {
                realm.add(challengeDB)
            }
        }
    }


    
}


extension String {
    func converToDouble() -> Double {
        let doubleValue = Double(self) ?? 0.0
        return doubleValue
    }
}
