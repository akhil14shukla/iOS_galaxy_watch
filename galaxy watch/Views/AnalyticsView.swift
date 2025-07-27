import SwiftUI
import Charts

struct AnalyticsView: View {
    @StateObject private var healthAnalytics = HealthAnalytics()
    @State private var selectedTimeframe: TimeFrame = .week
    @State private var showingDetailView = false
    @State private var selectedInsight: HealthInsight?
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Time frame selector
                    timeFrameSelector
                    
                    // Health insights
                    insightsSection
                    
                    // Charts section
                    chartsSection
                    
                    // Detailed metrics
                    metricsSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Health Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await healthAnalytics.analyzeWeeklyData()
                        }
                    }
                }
            }
            .sheet(item: $selectedInsight) { insight in
                InsightDetailView(insight: insight)
            }
            .onAppear {
                Task {
                    await healthAnalytics.analyzeWeeklyData()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var timeFrameSelector: some View {
        Picker("Time Frame", selection: $selectedTimeframe) {
            ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                Text(timeframe.rawValue).tag(timeframe)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Insights")
                .font(.headline)
                .padding(.horizontal)
            
            if healthAnalytics.isAnalyzing {
                ProgressView("Analyzing health data...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                let insights = healthAnalytics.getHealthInsights()
                
                if insights.isEmpty {
                    Text("No insights available. Make sure your Galaxy Watch is syncing health data.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(insights) { insight in
                            InsightCard(insight: insight) {
                                selectedInsight = insight
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Trends")
                .font(.headline)
                .padding(.horizontal)
            
            // Steps chart
            if !healthAnalytics.weeklyStepsTrend.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Steps")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Chart(healthAnalytics.weeklyStepsTrend) { data in
                        BarMark(
                            x: .value("Day", data.date, unit: .day),
                            y: .value("Steps", data.steps)
                        )
                        .foregroundStyle(data.goalReached ? Color.green : Color.orange)
                        
                        RuleMark(y: .value("Goal", healthAnalytics.dailyStepsGoal))
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                }
            }
            
            // Heart rate zones visualization
            if healthAnalytics.weeklyHeartRateAverage > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Heart Rate Zones")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    HeartRateZonesView(
                        currentRate: healthAnalytics.weeklyHeartRateAverage,
                        zones: healthAnalytics.heartRateZones
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    title: "Avg Heart Rate",
                    value: String(format: "%.0f BPM", healthAnalytics.weeklyHeartRateAverage),
                    icon: "heart.fill",
                    color: .red
                )
                
                MetricCard(
                    title: "Sleep Quality",
                    value: String(format: "%.0f%%", healthAnalytics.sleepQualityScore),
                    icon: "moon.fill",
                    color: .purple
                )
                
                MetricCard(
                    title: "Active Calories",
                    value: String(format: "%.0f kcal", healthAnalytics.activeCaloriesBurned),
                    icon: "flame.fill",
                    color: .orange
                )
                
                MetricCard(
                    title: "Step Goal Rate",
                    value: "\(goalAchievementRate)%",
                    icon: "target",
                    color: .green
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var goalAchievementRate: Int {
        let achievedDays = healthAnalytics.weeklyStepsTrend.filter(\.goalReached).count
        let totalDays = max(healthAnalytics.weeklyStepsTrend.count, 1)
        return Int((Double(achievedDays) / Double(totalDays)) * 100)
    }
}

struct InsightCard: View {
    let insight: HealthInsight
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: insight.icon)
                    .font(.title2)
                    .foregroundColor(insight.type.color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(insight.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct HeartRateZonesView: View {
    let currentRate: Double
    let zones: HealthAnalytics.HeartRateZones
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background zones
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [.blue, .green, .orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 30)
                
                // Current rate indicator
                GeometryReader { geometry in
                    let position = getPosition(for: currentRate, in: geometry.size.width)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 3, height: 40)
                        .position(x: position, y: geometry.size.height / 2)
                        .shadow(radius: 2)
                }
                .frame(height: 30)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Current: \(Int(currentRate)) BPM")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Zone: \(zones.getZone(for: currentRate))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Range: 60-200 BPM")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func getPosition(for rate: Double, in width: CGFloat) -> CGFloat {
        let minRate: Double = 60
        let maxRate: Double = 200
        let clampedRate = max(minRate, min(maxRate, rate))
        let percentage = (clampedRate - minRate) / (maxRate - minRate)
        return CGFloat(percentage) * width
    }
}

struct InsightDetailView: View {
    let insight: HealthInsight
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: insight.icon)
                            .font(.largeTitle)
                            .foregroundColor(insight.type.color)
                        
                        VStack(alignment: .leading) {
                            Text(insight.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(getDetailedTypeDescription())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Detailed message
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Analysis")
                            .font(.headline)
                        
                        Text(insight.message)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Recommendations
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendations")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(getRecommendations(), id: \.self) { recommendation in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    
                                    Text(recommendation)
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Insight Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getDetailedTypeDescription() -> String {
        switch insight.type {
        case .positive:
            return "Good indicators for your health"
        case .neutral:
            return "Areas with potential for improvement"
        case .warning:
            return "Requires attention and action"
        }
    }
    
    private func getRecommendations() -> [String] {
        switch insight.title {
        case "Heart Rate Analysis":
            return [
                "Maintain regular cardiovascular exercise",
                "Monitor stress levels and practice relaxation techniques",
                "Ensure adequate sleep and recovery",
                "Consider consulting a healthcare provider for personalized advice"
            ]
        case "Activity Level":
            return [
                "Set daily step goals and track progress",
                "Take regular breaks to walk throughout the day",
                "Use stairs instead of elevators when possible",
                "Park farther away or get off transit one stop early"
            ]
        case "Sleep Quality":
            return [
                "Maintain a consistent sleep schedule",
                "Create a relaxing bedtime routine",
                "Keep your bedroom cool, dark, and quiet",
                "Limit screen time before bed",
                "Avoid caffeine and large meals close to bedtime"
            ]
        default:
            return [
                "Continue monitoring your health metrics",
                "Stay consistent with healthy habits",
                "Consult healthcare providers when needed"
            ]
        }
    }
}
