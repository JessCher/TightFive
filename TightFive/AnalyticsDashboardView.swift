import SwiftUI
import SwiftUI
import SwiftData

/// Analytics Dashboard - Shows AI-powered performance insights
struct AnalyticsDashboardView: View {
    @Query(sort: \Performance.createdAt, order: .reverse) private var performances: [Performance]
    
    // Filter to only performances with analytics
    private var analyzedPerformances: [Performance] {
        performances.filter { $0.hasAnalytics }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if analyzedPerformances.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 20) {
                        overviewCards
                        recentInsights
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .tfBackground()
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TFTheme.yellow)
                        
                        TFWordmarkTitle(title: "Analytics", size: 22)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(TFTheme.yellow.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(TFTheme.yellow)
            }
            
            VStack(spacing: 8) {
                Text("No Analytics Yet")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                
                Text("Perform in Stage Mode to get\nAI-powered insights about your show")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
    
    // MARK: - Overview Cards
    
    private var overviewCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                overviewCard(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    value: "\(analyzedPerformances.count)",
                    label: "Analyzed Shows"
                )
                
                overviewCard(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .cyan,
                    value: averageConfidenceString,
                    label: "Avg Confidence"
                )
            }
            
            HStack(spacing: 12) {
                overviewCard(
                    icon: "clock.fill",
                    color: .orange,
                    value: totalTimeString,
                    label: "Total Time"
                )
                
                overviewCard(
                    icon: "star.fill",
                    color: TFTheme.yellow,
                    value: "\(topRatedCount)",
                    label: "Excellent"
                )
            }
        }
    }
    
    private func overviewCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tfDynamicCard(cornerRadius: 16)
    }
    
    // MARK: - Recent Insights
    
    private var recentInsights: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Insights")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                NavigationLink {
                    AllInsightsView(performances: analyzedPerformances)
                } label: {
                    Text("See All")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TFTheme.yellow)
                }
            }
            
            VStack(spacing: 10) {
                ForEach(recentInsightsList.prefix(5)) { insight in
                    NavigationLink {
                        InsightDetailView(insight: insight.insight, performance: insight.performance)
                    } label: {
                        InsightRow(insight: insight.insight)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var averageConfidenceString: String {
        let insights = analyzedPerformances.flatMap { $0.insights ?? [] }
        guard !insights.isEmpty else { return "N/A" }
        
        let confidentShows = insights.filter { insight in
            insight.type == .highPerformance && 
            (insight.severity == .info || insight.title.contains("Excellent") || insight.title.contains("Solid"))
        }.count
        
        let percentage = Double(confidentShows) / Double(analyzedPerformances.count) * 100
        return "\(Int(percentage))%"
    }
    
    private var totalTimeString: String {
        let total = analyzedPerformances.reduce(0.0) { $0 + $1.duration }
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var topRatedCount: Int {
        analyzedPerformances.filter { performance in
            guard let insights = performance.insights else { return false }
            return insights.contains { $0.title.contains("Excellent") }
        }.count
    }
    
    private struct InsightWithPerformance: Identifiable {
        let id: UUID
        let insight: PerformanceAnalytics.Insight
        let performance: Performance
    }
    
    private var recentInsightsList: [InsightWithPerformance] {
        var list: [InsightWithPerformance] = []
        
        for performance in analyzedPerformances.prefix(10) {
            if let insights = performance.insights {
                for insight in insights {
                    list.append(InsightWithPerformance(
                        id: insight.id,
                        insight: insight,
                        performance: performance
                    ))
                }
            }
        }
        
        return list.sorted { $0.insight.timestamp > $1.insight.timestamp }
    }
}

// MARK: - Insight Row Component

struct InsightRow: View {
    let insight: PerformanceAnalytics.Insight
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(12)
        .tfDynamicCard(cornerRadius: 12)
    }
    
    private var icon: String {
        switch insight.type {
        case .lowConfidence:
            return "exclamationmark.triangle.fill"
        case .paceChange:
            return "speedometer"
        case .longPause:
            return "pause.circle.fill"
        case .highPerformance:
            return insight.title.contains("Excellent") ? "star.fill" : "checkmark.circle.fill"
        case .anchorSuggestion:
            return "lightbulb.fill"
        }
    }
    
    private var iconColor: Color {
        switch insight.severity {
        case .info:
            return insight.type == .highPerformance && insight.title.contains("Excellent") ? 
                TFTheme.yellow : .cyan
        case .suggestion:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - All Insights View

struct AllInsightsView: View {
    let performances: [Performance]
    
    @State private var selectedFilter: InsightFilter = .all
    
    enum InsightFilter: String, CaseIterable {
        case all = "All"
        case critical = "Critical"
        case suggestions = "Suggestions"
        case performance = "Performance"
        
        var icon: String {
            switch self {
            case .all: return "chart.bar.fill"
            case .critical: return "exclamationmark.triangle.fill"
            case .suggestions: return "lightbulb.fill"
            case .performance: return "star.fill"
            }
        }
    }
    
    private var allInsights: [(insight: PerformanceAnalytics.Insight, performance: Performance)] {
        var list: [(insight: PerformanceAnalytics.Insight, performance: Performance)] = []
        
        for performance in performances {
            if let insights = performance.insights {
                for insight in insights {
                    list.append((insight, performance))
                }
            }
        }
        
        return list.sorted { $0.insight.timestamp > $1.insight.timestamp }
    }
    
    private var filteredInsights: [(insight: PerformanceAnalytics.Insight, performance: Performance)] {
        switch selectedFilter {
        case .all:
            return allInsights
        case .critical:
            return allInsights.filter { $0.insight.severity == .critical || $0.insight.severity == .warning }
        case .suggestions:
            return allInsights.filter { $0.insight.type == .anchorSuggestion || $0.insight.severity == .suggestion }
        case .performance:
            return allInsights.filter { $0.insight.type == .highPerformance }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                filterPicker
                
                VStack(spacing: 10) {
                    ForEach(filteredInsights, id: \.insight.id) { item in
                        NavigationLink {
                            InsightDetailView(insight: item.insight, performance: item.performance)
                        } label: {
                            InsightRowWithPerformance(insight: item.insight, performance: item.performance)
                        }
                    }
                }
            }
            .padding(16)
        }
        .tfBackground()
        .navigationTitle("All Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(InsightFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? TFTheme.yellow : Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

struct InsightRowWithPerformance: View {
    let insight: PerformanceAnalytics.Insight
    let performance: Performance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(insight.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Text(insight.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            
            HStack(spacing: 6) {
                Text(performance.displayTitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                
                Text("•")
                    .foregroundStyle(.white.opacity(0.3))
                
                Text(performance.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(12)
        .tfDynamicCard(cornerRadius: 12)
    }
    
    private var icon: String {
        switch insight.type {
        case .lowConfidence:
            return "exclamationmark.triangle.fill"
        case .paceChange:
            return "speedometer"
        case .longPause:
            return "pause.circle.fill"
        case .highPerformance:
            return insight.title.contains("Excellent") ? "star.fill" : "checkmark.circle.fill"
        case .anchorSuggestion:
            return "lightbulb.fill"
        }
    }
    
    private var iconColor: Color {
        switch insight.severity {
        case .info:
            return insight.type == .highPerformance && insight.title.contains("Excellent") ? 
                TFTheme.yellow : .cyan
        case .suggestion:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - Insight Detail View

struct InsightDetailView: View {
    let insight: PerformanceAnalytics.Insight
    let performance: Performance
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(insight.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 6) {
                            Text(severityLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(iconColor)
                            
                            Text("•")
                                .foregroundStyle(.white.opacity(0.3))
                            
                            Text(insight.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                
                // Detail
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(insight.detail)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                .padding(16)
                .tfDynamicCard(cornerRadius: 16)
                
                // Line Range (if applicable)
                if let lineRange = insight.lineRange {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Affected Lines")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(TFTheme.yellow)
                            
                            Text("Lines \(lineRange.lowerBound) - \(lineRange.upperBound)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            
                            Spacer()
                        }
                        .padding(14)
                        .background(TFTheme.yellow.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                // Performance Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Performance")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    VStack(spacing: 10) {
                        infoRow(icon: "text.book.closed", label: "Show", value: performance.displayTitle)
                        infoRow(icon: "calendar", label: "Date", value: performance.formattedDate)
                        infoRow(icon: "clock", label: "Duration", value: performance.formattedDuration)
                        
                        if !performance.venue.isEmpty {
                            infoRow(icon: "building.2", label: "Venue", value: performance.venue)
                        }
                    }
                }
                .padding(16)
                .tfDynamicCard(cornerRadius: 16)
            }
            .padding(16)
        }
        .tfBackground()
        .navigationTitle("Insight")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
    }
    
    private var icon: String {
        switch insight.type {
        case .lowConfidence:
            return "exclamationmark.triangle.fill"
        case .paceChange:
            return "speedometer"
        case .longPause:
            return "pause.circle.fill"
        case .highPerformance:
            return insight.title.contains("Excellent") ? "star.fill" : "checkmark.circle.fill"
        case .anchorSuggestion:
            return "lightbulb.fill"
        }
    }
    
    private var iconColor: Color {
        switch insight.severity {
        case .info:
            return insight.type == .highPerformance && insight.title.contains("Excellent") ? 
                TFTheme.yellow : .cyan
        case .suggestion:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
    
    private var severityLabel: String {
        switch insight.severity {
        case .info: return "INFO"
        case .suggestion: return "SUGGESTION"
        case .warning: return "WARNING"
        case .critical: return "CRITICAL"
        }
    }
}
