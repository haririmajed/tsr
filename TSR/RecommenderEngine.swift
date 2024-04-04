//
//  RecommenderEngine.swift
//  TSR
//
//  Created by Majed Hariri on 2/19/24.
//

import Foundation
import CreateML
import CoreML
import TabularData
import MLCompute
import UIKit
import CreateMLComponents

enum PredictionType {
    case time
    case repetitions
    case notification
}

class RecommenderEngine {
    static let shared = RecommenderEngine()
    
    // MARK: - Prediction Methods
    
    /**
     ## Summary:
     This function `prepareDataForPrediction` processes and structures data for machine learning predictions based on the specified prediction type.
     
     - Parameter type: An enum value of `PredictionType`, indicating whether the data preparation is for 'repetitions' or another type of prediction.
     
     - Returns: A tuple containing an array of features (each a dictionary of String to Double) and an array of targets (Double), structured for use in machine learning models.
     
     ### Usage:
     Utilize this function to convert raw progress data into a structured format suitable for machine learning predictions. This involves organizing data into features and targets based on the specified `type` of prediction.
     
     ### Example:
     ```
     let (features, targets) = prepareDataForPrediction(type: .repetitions)
     print(features) // Example output: [["points": 100.0, "hour": 8.0], ["points": 150.0, "hour": 9.0], ...]
     print(targets) // Example output: [10.0, 15.0, ...]
     ```
     ### Why we need it:
     Structuring raw data into a standardized format is essential for feeding into machine learning models for training or prediction. This function facilitates this by segmenting data into features and targets according to the needs of the specific prediction task.
     
     ### Notes:
     The function differentiates the data preparation based on the prediction `type`: if predicting 'repetitions', it sets 'points' and 'hour' as features and 'repetitions' as targets; for other types, it sets 'points' and 'repetitions' as features, and 'hour' as targets.
     
     ### Best Practices:
     Ensure that the `progressData` retrieved from `ProgressManager` is valid and up-to-date. Handle edge cases where data might be missing or incorrect to maintain the integrity of the training or prediction process.
     */
    private
    func prepareDataForPrediction(type: PredictionType) -> (features: [[String: Double]], targets: [Double]) {
        let progressData = ProgressManager.shared.getProgress()
        var features: [[String: Double]] = []
        var targets: [Double] = []
        if type == .repetitions {
            for progress in progressData {
                let feature = ["points": Double(progress.points), "hour": Double(progress.hour)]
                features.append(feature)
                targets.append(Double(progress.repetitions))
            }
            
            return (features, targets)
        } else {
            for progress in progressData {
                let feature = ["points": Double(progress.points), "repetitions": Double(progress.repetitions)]
                features.append(feature)
                targets.append(Double(progress.hour))
            }
            return (features, targets)
        }
    }
    
    /**
     ## Summary:
     This function `trainModel` trains a machine learning model for predicting progress based on the specified prediction type.
     
     - Parameters:
     - type: An enum value of `PredictionType`, indicating the type of prediction for which the model will be trained.
     - completion: A closure that takes an optional `MLLinearRegressor` as its parameter, which is called upon completion of the model training.
     
     ### Usage:
     Use this function to train a machine learning model for predicting progress based on the specified `type` of prediction. The completion closure is called with the trained model upon completion of the training process.
     
     ### Example:
     ```
     trainModel(type: .time) { regressor in
     if let regressor = regressor {
     print("Model trained successfully!")
     } else {
     print("Model training failed.")
     }
     }
     ```
     ### Why we need it:
     Training a machine learning model is essential for making accurate predictions based on historical data. This function automates the training process based on the specified prediction type, providing a trained model for use in making predictions.
     
     ### Notes:
     The function uses the `MLLinearRegressor` class from the `CreateML` framework to train a linear regression model. The training process is asynchronous, and the completion closure is called with the trained model upon completion of the training process.
     */
    func trainModel(type: PredictionType, completion: @escaping (MLLinearRegressor?) -> Void) {
        // Move the model training to a background thread
        DispatchQueue.global(qos: .background).async {
            let (features, targets) = self.prepareDataForPrediction(type: type)
            var trainingData = DataFrame()
            
            // Utilize Swift's more efficient data manipulation methods
            let featureKeys = Set(features.flatMap { $0.keys })
            
            // Reconstruct the loop to minimize the overhead
            for key in featureKeys {
                let columnContents = features.map { $0[key, default: 0.0] } // More efficient map usage
                trainingData.append(column: Column(name: key, contents: columnContents))
            }
            trainingData.append(column: Column(name: "target", contents: targets))
            
            do {
                // Perform model training
                let regressor = try MLLinearRegressor(trainingData: trainingData, targetColumn: "target")
                
                // Switch back to the main thread for the completion handler
                DispatchQueue.main.async {
                    completion(regressor)
                }
            } catch {
                print("Error training model: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    
    /**
        ## Summary:
        This function `predict` makes a prediction using a trained regressor model based on the provided progress model and prediction type.
        
        - Parameters:
        - progressModel: A `ProgressModel` object containing the progress data for which a prediction will be made.
        - regressor: An `MLLinearRegressor` object representing the trained machine learning model.
        - type: An enum value of `PredictionType`, indicating the type of prediction to be made.
        
        - Returns: A `Double` value representing the predicted outcome based on the provided progress model and prediction type.
        
        ### Usage:
        Utilize this function to make a prediction using a trained machine learning model based on the provided `progressModel` and `type` of prediction. The function returns the predicted outcome as a `Double` value.
        
        ### Example:
        ```
        let regressor = MLLinearRegressor()
        let prediction = predict(forProgressModel: progressModel, usingRegressor: regressor, type: .time)
        ```
        ### Why we need it:
        Making predictions based on historical data is essential for forecasting future outcomes or trends. This function automates the prediction process based on a trained machine learning model, providing a predicted outcome based on the provided progress model and prediction type.
        
        ### Notes:
        The function prepares the input data based on the prediction `type` and attempts to make a prediction using the provided `regressor`. If an error occurs during the prediction process, a default value of 0.0 is returned.
    
    */
    func predict(forProgressModel progressModel: ProgressModel, usingRegressor regressor: MLLinearRegressor, type: PredictionType) -> Double {
        // Prepare input data based on the prediction type
        let feature: [String: Double] = {
            switch type {
            case .time:
                return ["points": Double(progressModel.points), "repetitions": Double(progressModel.repetitions)]
            case .repetitions:
                return ["points": Double(progressModel.points), "hour": Double(progressModel.hour)]
            default: // Covers .day or any other types
                return ["points": Double(progressModel.points), "hour": Double(progressModel.hour)]
            }
        }()
        
        // Convert feature dictionary into a DataFrame
        var inputData = DataFrame()
        for (key, value) in feature {
            inputData.append(column: Column(name: key, contents: [value]))
        }
        
        // Attempt to make a prediction using the regressor
        do {
            let predictions = try regressor.predictions(from: inputData)
            return predictions.compactMap({ $0 as? Double }).first ?? 0.0 // Extract the first Double value, if available
        } catch {
            print("Error making prediction: \(error.localizedDescription)")
            return 0.0 // Return a default value on error
        }
    }
    
    
    

    /**
     ## Summary:
     This function `extractHours` extracts the hours from the provided array of `OpenAppHours` objects.
     
     - Parameter data: An array of `OpenAppHours` objects from which the hours will be extracted.
     
     - Returns: An array of integers representing the hours extracted from the `OpenAppHours` objects.
     
     ### Usage:
     Use this function to retrieve an array of hours (as integers) from a given array of `OpenAppHours` objects. This is particularly useful when you need to process or analyze the operational hours of an application or service.
     
     ### Example:
     ```
     let appHours = [OpenAppHours(hour: 9), OpenAppHours(hour: 10), OpenAppHours(hour: 11)]
     let hours = extractHours(from: appHours)
     print(hours) // Prints: [9, 10, 11]
     ```
     
     ### Why we need it:
     Extracting specific pieces of data, like hours, from complex data structures is common in time-related analyses, such as scheduling, reporting, or monitoring app usage patterns. This function simplifies the extraction process, making it more efficient and readable.
     
     ### Notes:
     The function iterates through the `OpenAppHours` array, extracting the `hour` property from each object and returning an array of these hours.
     */
    private
    func extractHours(from data: [OpenAppHours]) -> [Int] {
        return data.map { $0.hour }
    }
    
    
    /**
     ## Summary:
     This function `createFrequencyDictionary` creates a dictionary mapping each unique hour to its frequency from the provided array of integers.
     
     - Parameter hours: An array of integers representing hours, from which the frequency of each hour will be calculated.
     
     - Returns: A dictionary where each key is an hour (from the input array) and its value is the frequency of that hour in the array.
     
     ### Usage:
     Use this function to create a frequency dictionary from an array of hours. This can be helpful for identifying the most or least common hours, analyzing usage patterns, or scheduling based on the frequency of certain hours.
     
     ### Example:
     ```
     let hours = [9, 10, 11, 9, 10]
     let frequency = createFrequencyDictionary(from: hours)
     print(frequency) // Prints: [9: 2, 10: 2, 11: 1]
     ```
     
     ### Why we need it:
     Analyzing the frequency of specific values (e.g., hours, days, or categories) is a common task in data processing and analysis. This function simplifies the process by providing a dictionary with the frequency of each unique value, making it easier to identify patterns and trends.
     
     ### Notes:
     The function uses the `Dictionary(grouping:by:)` initializer to group the hours by their value and then maps the counts to the corresponding hours.
     
     ### Warning:
     The function assumes that the input array contains valid hours (e.g., integers between 0 and 23). If the input data is not properly validated, the function may produce unexpected results or errors.
     
     */
    private
    func createFrequencyDictionary(from hours: [Int]) -> [Int: Int] {
        return Dictionary(grouping: hours, by: { $0 })
            .mapValues { $0.count }
    }
    
    /**
     ## Summary:
     This function `sortHoursByFrequency` sorts the hours based on their frequency from a given frequency dictionary.
     
     - Parameter frequencyDict: A dictionary where each key is an hour and each value is the frequency of that hour.
     
     - Returns: An array of tuples, where each tuple contains an hour and its corresponding frequency, sorted by frequency in descending order.
     
     ### Usage:
     Utilize this function to order hours from the most frequent to the least frequent based on a provided frequency dictionary. This is particularly useful for scheduling, prioritizing tasks, or understanding peak times in time-related data analyses.
     
     ### Example:
     ```
     let frequencyDict = [9: 2, 10: 2, 11: 1]
     let sortedHours = sortHoursByFrequency(frequencyDict)
     print(sortedHours) // Prints: [(9, 2), (10, 2), (11, 1)]
     ```
     ### Why we need it:
     Sorting hours by frequency aids in identifying peak and off-peak hours, which is beneficial for planning, resource allocation, or understanding user behavior. This function automates the sorting process based on frequency, facilitating quicker and more informed decision-making.
     
     ### Notes:
     The sorting is performed in descending order based on frequency, so the hour with the highest frequency is listed first. If two hours have the same frequency, they are sorted by the hour value in ascending order.
     
     */
    private
    func sortHoursByFrequency(_ frequencyDict: [Int: Int]) -> [(Int, Int)] {
        return frequencyDict.sorted { $0.value > $1.value }
    }
    
    /**
     ## Summary:
     This function `selectPredictionTimes` selects hours from a sorted list based on a minimum gap and a maximum count criteria.
     
     - Parameters:
     - sortedHours: A list of tuples, each containing an hour and its frequency, sorted by frequency.
     - minGap: The minimum gap (in hours) required between consecutive selected times. Default is 2 hours.
     - maxCount: The maximum number of hours to select. Default is 4.
     
     - Returns: An array of integers representing the selected prediction times.
     
     ### Usage:
     Employ this function to select specific hours from a sorted list, ensuring there is a minimum time gap between each. This can be useful in scheduling predictions, appointments, or other time-sensitive tasks where a minimum time separation is necessary.
     
     ### Example:
     ```
     let sortedHours = [(9, 2), (10, 2), (11, 1)]
     let predictionTimes = selectPredictionTimes(from: sortedHours)
     print(predictionTimes) // Prints: [9, 10]
     ```
     
     ### Why we need it:
     This function aids in creating a schedule or plan that adheres to time constraints, such as ensuring a certain amount of downtime or preparation time between events. It helps in maintaining efficiency while respecting predefined temporal boundaries.
     
     ### Notes:
     The selection process respects the order of `sortedHours`, prioritizing hours with higher frequencies while ensuring that the `minGap` and `maxCount` conditions are met.
     */
    private
    func selectPredictionTimes(from sortedHours: [(Int, Int)], minGap: Int = 2, maxCount: Int = 4) -> [Int] {
        var predictionTimes: [Int] = []
        var lastHour = -minGap
        
        for (hour, _) in sortedHours {
            if hour - lastHour >= minGap {
                predictionTimes.append(hour)
                lastHour = hour
            }
            
            if predictionTimes.count == maxCount {
                break
            }
        }
        return predictionTimes
    }
    
    /**
     ## Summary:
     This function `addDefaultTimes` integrates default time values into an existing list of prediction times, respecting a minimum time gap.
     
     - Parameters:
     - predictionTimes: An array of integers representing existing prediction times.
     - defaultTimes: An array of integers representing default times to potentially add to the prediction times.
     - minGap: The minimum gap (in hours) required between any two times. Default is 2 hours.
     
     - Returns: An array of integers representing the updated list of prediction times, sorted and integrated with default times while respecting the minimum gap.
     
     ### Usage:
     Utilize this function to supplement a list of prediction times with default times, ensuring no two times are closer together than the specified minimum gap. This is useful for scheduling or planning where default slots need to be filled in an existing schedule.
     
     ### Example:
     ```
     let predictionTimes = [9, 14, 18]
     let defaultTimes = [8, 10, 12, 16, 20]
     let updatedTimes = addDefaultTimes(to: predictionTimes, defaultTimes: defaultTimes)
     print(updatedTimes) // Example output: [10, 12, 14, 18]
     ```
     ### Why we need it:
     This function ensures that an existing schedule incorporates essential or preferred default times, enhancing the schedule's utility or compliance with certain standards or expectations while maintaining specified time separations.
     
     ### Notes:
     The function first sorts the existing `predictionTimes` to maintain chronological order. It then attempts to insert each `defaultTime` into the sorted list, provided it adheres to the `minGap` requirement with adjacent times.
     
     ### Recommendations:
     It's advisable to use distinct, non-overlapping values for `defaultTimes` to prevent redundancy and ensure a wide coverage of time slots within the scheduling constraints defined by `minGap`.
     */
    
    private
    func addDefaultTimes(to predictionTimes: [Int], defaultTimes: [Int], minGap: Int = 2) -> [Int] {
        var updatedPredictionTimes = predictionTimes.sorted()
        
        for defaultTime in defaultTimes {
            if let insertionIndex = findInsertionIndex(in: updatedPredictionTimes, for: defaultTime, minGap: minGap) {
                updatedPredictionTimes.insert(defaultTime, at: insertionIndex)
            }
            
            if updatedPredictionTimes.count >= 4 {
                break
            }
        }
        
        return updatedPredictionTimes
    }
    
    /**
     ## Summary:
     This function `findInsertionIndex` identifies the index at which a given time should be inserted into a sorted list, respecting a minimum time gap.
     
     - Parameters:
     - times: A sorted array of integers representing existing times.
     - defaultTime: An integer representing the time to be inserted into the list.
     - minGap: The minimum gap (in hours) required between any two times.
     
     - Returns: An optional integer representing the index at which the `defaultTime` should be inserted, or `nil` if no suitable index is found.
     
     ### Usage:
     Use this function to determine the appropriate position for inserting a time into a sorted list, ensuring that the time separation between adjacent times meets a specified minimum requirement. This is particularly useful for scheduling or planning where time slots need to be added while maintaining temporal constraints.
     
     ### Example:
     ```
     let times = [9, 14, 18]
     let defaultTime = 12
     let insertionIndex = findInsertionIndex(in: times, for: defaultTime, minGap: 2)
     print(insertionIndex) // Example output: 2
     ```
     ### Why we need it:
     This function facilitates the insertion of new times into an existing schedule, ensuring that the temporal order and separation between times are maintained according to predefined constraints. It helps in creating efficient and compliant schedules or plans.
     
     ### Notes:
     The function iterates through the sorted `times` array, identifying the first suitable position for inserting the `defaultTime` while respecting the `minGap` requirement. If no suitable position is found, the function returns `nil`.
     */
    private
    func findInsertionIndex(in times: [Int], for defaultTime: Int, minGap: Int) -> Int? {
        // for (index, time) in times.enumerated() {
        //     if defaultTime - time >= minGap {
        //         if index + 1 < times.count {
        //             if times[index + 1] - defaultTime >= minGap {
        //                 return index + 1
        //             }
        //         } else {
        //             return index + 1
        //         }
        //     }
        // }
        // return nil
        let index = times.firstIndex { abs($0 - defaultTime) >= minGap }
        return index
    }
    
    /**
     ## Summary:
     This function `predictNotificationTimes` predicts the best times for sending notifications based on user historical data.
     
     - Parameters:
     - defaultTimes: An array of integers representing default notification times. Default is `[8, 10, 12, 16, 20]`.
     
     - Returns: An array of integers representing the predicted notification times, sorted and potentially supplemented with default times.
     
     ### Usage:
     Utilize this function to predict the best times for sending notifications to users based on their historical data. This is particularly useful for optimizing user engagement, scheduling reminders, or planning communication based on user activity patterns.
     
     ### Example:
     ```
     let notificationTimes = predictNotificationTimes()
     print(notificationTimes) // Example output: [10, 12, 16, 20]
     ```
     ### Why we need it:
     Predicting the best times for sending notifications can significantly improve user engagement and response rates. This function automates the prediction process based on user historical data, ensuring that notifications are delivered at optimal times.
     
     ### Notes:
     The function first retrieves the user's historical data and processes it to identify the best notification times. If the historical data is insufficient, the function supplements the prediction with default times to ensure a comprehensive coverage of potential notification slots.
     */
    func predictNotificationTimes(defaultTimes: [Int] = [8, 10, 12, 16, 20]) -> [Int] {
        let userHistoricalData = OpenAppHoursManager.shared.getAllOpenAppHours()
        
        guard !userHistoricalData.isEmpty else {
            return defaultTimes
        }
        
        let hours = extractHours(from: userHistoricalData)
        let frequencyDict = createFrequencyDictionary(from: hours)
        let sortedHours = sortHoursByFrequency(frequencyDict)
        var predictionTimes = selectPredictionTimes(from: sortedHours)
        predictionTimes = predictionTimes.sorted()

        // let's make sure that the prediction times are between 8 and 22 otherwise remove them from the list
        predictionTimes = predictionTimes.filter { $0 >= 8 && $0 <= 22 }
        
        guard !predictionTimes.isEmpty else {
            return defaultTimes
        }
        
        if predictionTimes.count < 5 {
            predictionTimes = addDefaultTimes(to: predictionTimes, defaultTimes: defaultTimes)
        }

        
        predictionTimes = Array(Set(predictionTimes))
        if predictionTimes.count > 4 {
            predictionTimes = Array(predictionTimes.prefix(4))
        }

        
        predictionTimes = predictionTimes.sorted()
        
        return predictionTimes
    }
    
}


