import Foundation
import HealthKit
import Charts
import SwiftUI

/// Advanced health data analytics and insights
class HealthAnalytics: ObservableObject {
    @Published var weeklyHeartRateAverage: Double = 0
    @Published var dailyStepsGoal: Int = 10000
    @Published var weeklyStepsTrend: [StepData] = []
    @Published var heartRateZones: HeartRateZones = HeartRateZones()
    @Published var sleepQualityScore: Double = 0
    @Published var activeCaloriesBurned: Double = 0
    @Published var isAnalyzing = false
    
    private let healthStore = HKHealthStore()
    
    struct StepData: Identifiable {
        let id = UUID()
        let date: Date
        let steps: Int
        let goalReached: Bool
    }
    
    struct HeartRateZones {
        var resting: ClosedRange<Double> = 60...100
        var fatBurn: ClosedRange<Double> = 101...140
        var cardio: ClosedRange<Double> = 141...170
        var peak: ClosedRange<Double> = 171...200
        
        func getZone(for heartRate: Double) -> String {
            switch heartRate {
            case resting: return "Resting"
            case fatBurn: return "Fat Burn"
            case cardio: return "Cardio"
            case peak: return "Peak"
            default: return "Unknown"
            }
        }
        
        func getZoneColor(for heartRate: Double) -> Color {
            switch heartRate {
            case resting: return .blue
            case fatBurn: return .green
            case cardio: return .orange
            case peak: return .red
            default: return .gray
            }
        }
    }
    
    // MARK: - Analysis Functions
    
    func analyzeWeeklyData() async {
        await MainActor.run { isAnalyzing = true }
        
        do {
            async let heartRateTask = calculateWeeklyHeartRateAverage()
            async let stepsTask = analyzeWeeklySteps()
            async let sleepTask = analyzeSleepQuality()
            async let caloriesTask = calculateActiveCalories()
            
            let (heartRate, steps, sleep, calories) = await (
                heartRateTask, stepsTask, sleepTask, caloriesTask
            )
            
            await MainActor.run {
                self.weeklyHeartRateAverage = heartRate
                self.weeklyStepsTrend = steps
                self.sleepQualityScore = sleep
                self.activeCaloriesBurned = calories
                self.isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                self.isAnalyzing = false
            }
            print("Error analyzing health data: \(error)")
        }
    }
    
    private func calculateWeeklyHeartRateAverage() async -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, _ in
                let average = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                continuation.resume(returning: average)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func analyzeWeeklySteps() async -> [StepData] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: DateComponents(day: 1)
            )
            
            query.initialResultsHandler = { _, results, _ in
                var stepData: [StepData] = []
                
                results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let steps = Int(statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    let data = StepData(
                        date: statistics.startDate,
                        steps: steps,
                        goalReached: steps >= self.dailyStepsGoal
                    )
                    stepData.append(data)
                }
                
                continuation.resume(returning: stepData)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func analyzeSleepQuality() async -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 0
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                
                var totalSleepHours = 0.0
                var nights = 0
                
                let groupedByNight = Dictionary(grouping: sleepSamples) { sample in
                    calendar.startOfDay(for: sample.startDate)
                }
                
                for (_, nightSamples) in groupedByNight {
                    let nightSleep = nightSamples.reduce(0.0) { total, sample in
                        let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600 // hours
                        return total + duration
                    }
                    
                    if nightSleep > 0 {
                        totalSleepHours += nightSleep
                        nights += 1
                    }
                }
                
                let averageSleepHours = nights > 0 ? totalSleepHours / Double(nights) : 0
                
                // Sleep quality score based on 7-9 hours optimal range
                let score = min(max((averageSleepHours - 4) / 5 * 100, 0), 100)
                continuation.resume(returning: score)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func calculateActiveCalories() async -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let total = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: total)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Insights and Recommendations
    
    func getHealthInsights() -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Heart rate insights
        if weeklyHeartRateAverage > 0 {
            let insight = HealthInsight(
                title: "Heart Rate Analysis",
                message: getHeartRateInsight(),
                type: getHeartRateInsightType(),
                icon: "heart.fill"
            )
            insights.append(insight)
        }
        
        // Steps insights
        let weeklyStepsAverage = weeklyStepsTrend.isEmpty ? 0 : 
            weeklyStepsTrend.reduce(0) { $0 + $1.steps } / weeklyStepsTrend.count
        
        if weeklyStepsAverage > 0 {
            let insight = HealthInsight(
                title: "Activity Level",
                message: getStepsInsight(average: weeklyStepsAverage),
                type: getStepsInsightType(average: weeklyStepsAverage),
                icon: "figure.walk"
            )
            insights.append(insight)
        }
        
        // Sleep insights
        if sleepQualityScore > 0 {
            let insight = HealthInsight(
                title: "Sleep Quality",
                message: getSleepInsight(),
                type: getSleepInsightType(),
                icon: "moon.fill"
            )
            insights.append(insight)
        }
        
        return insights
    }
    
    private func getHeartRateInsight() -> String {
        switch weeklyHeartRateAverage {
        case 0..<60:
            return "Your resting heart rate is quite low. This could indicate excellent fitness or potential health concerns. Consider consulting a healthcare provider."
        case 60...100:
            return "Your heart rate is in the normal range. Keep up the good work with regular exercise!"
        case 101...120:
            return "Your heart rate is slightly elevated. Consider stress management and regular cardio exercise."
        default:
            return "Your heart rate appears elevated. Please consult with a healthcare provider for evaluation."
        }
    }
    
    private func getHeartRateInsightType() -> HealthInsight.InsightType {
        switch weeklyHeartRateAverage {
        case 60...100: return .positive
        case 0..<60, 101...120: return .neutral
        default: return .warning
        }
    }
    
    private func getStepsInsight(average: Int) -> String {
        switch average {
        case 0..<5000:
            return "Try to increase your daily activity. Start with short walks and gradually build up."
        case 5000..<8000:
            return "You're moderately active! Try to reach 10,000 steps daily for optimal health benefits."
        case 8000..<12000:
            return "Great job! You're meeting recommended activity levels."
        default:
            return "Excellent! You're very active. Keep up the fantastic work!"
        }
    }
    
    private func getStepsInsightType(average: Int) -> HealthInsight.InsightType {
        switch average {
        case 0..<5000: return .warning
        case 5000..<8000: return .neutral
        default: return .positive
        }
    }
    
    private func getSleepInsight() -> String {
        switch sleepQualityScore {
        case 0..<40:
            return "Your sleep quality could be improved. Try to maintain a consistent sleep schedule and create a relaxing bedtime routine."
        case 40..<70:
            return "Your sleep is okay, but there's room for improvement. Aim for 7-9 hours of quality sleep."
        default:
            return "Excellent sleep quality! You're getting good rest, which is crucial for health and recovery."
        }
    }
    
    private func getSleepInsightType() -> HealthInsight.InsightType {
        switch sleepQualityScore {
        case 0..<40: return .warning
        case 40..<70: return .neutral
        default: return .positive
        }
    }
}

struct HealthInsight: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: InsightType
    let icon: String
    
    enum InsightType {
        case positive, neutral, warning
        
        var color: Color {
            switch self {
            case .positive: return .green
            case .neutral: return .blue
            case .warning: return .orange
            }
        }
    }
}
