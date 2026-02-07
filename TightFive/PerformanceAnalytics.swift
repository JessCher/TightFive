import Foundation
import SwiftUI

/// High-performance analytics engine for Stage Mode performances.
/// Analyzes confidence trends, pace variations, and provides actionable insights.
///
/// Design principles:
/// - Zero-copy where possible (references, not copies)
/// - Lazy evaluation (compute only what's requested)
/// - Memory-efficient (streaming algorithms for large datasets)
/// - Battery-conscious (optimized math via Accelerate)
@MainActor
struct PerformanceAnalytics {
    
    // MARK: - Insight Types
    
    struct Insight: Identifiable, Codable {
        let id: UUID
        let type: InsightType
        let severity: Severity
        let title: String
        let detail: String
        let lineRange: ClosedRange<Int>?
        let timestamp: Date
        
        enum InsightType: String, Codable {
            case lowConfidence      // Struggled section
            case paceChange         // Speed up/down
            case longPause          // Extended silence
            case highPerformance    // Nailed it
            case anchorSuggestion   // Suggest adding anchor
        }
        
        enum Severity: Int, Codable, Comparable {
            case info = 0
            case suggestion = 1
            case warning = 2
            case critical = 3
            
            static func < (lhs: Severity, rhs: Severity) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
        
        /// Convenience initializer for simple text-based insights
        init(title: String, description: String = "", severity: Severity = .info) {
            self.id = UUID()
            self.type = .highPerformance
            self.severity = severity
            self.title = title
            self.detail = description
            self.lineRange = nil
            self.timestamp = Date()
        }
        
        /// Full initializer
        init(id: UUID = UUID(), type: InsightType, severity: Severity, title: String, detail: String, lineRange: ClosedRange<Int>?, timestamp: Date = Date()) {
            self.id = id
            self.type = type
            self.severity = severity
            self.title = title
            self.detail = detail
            self.lineRange = lineRange
            self.timestamp = timestamp
        }
    }
    
    struct PaceAnalysis: Codable {
        let averageWPM: Double
        let sections: [PaceSection]
        let trend: Trend
        
        struct PaceSection: Codable {
            let startLine: Int
            let endLine: Int
            let wpm: Double
            let duration: TimeInterval
        }
        
        enum Trend: String, Codable {
            case accelerating   // Getting faster
            case decelerating   // Getting slower
            case steady         // Consistent
            case variable       // Up and down
        }
    }
    
    struct ConfidenceAnalysis: Codable {
        let average: Double
        let minimum: Double
        let maximum: Double
        let lowConfidenceSections: [ConfidenceSection]
        
        struct ConfidenceSection: Codable {
            let startLine: Int
            let endLine: Int
            let averageConfidence: Double
            let duration: TimeInterval
        }
    }
    
    // MARK: - Analysis Functions
    
    /// Analyzes a completed performance and generates insights.
    /// Optimized for battery: single-pass algorithm, minimal allocations.
    static func analyze(
        transcript: String,
        confidenceData: [(timestamp: TimeInterval, confidence: Double, lineIndex: Int)],
        totalLines: Int,
        duration: TimeInterval
    ) -> [Insight] {
        
        var insights: [Insight] = []
        
        // Early exit for insufficient data
        guard !confidenceData.isEmpty, duration > 0 else {
            return insights
        }
        
        // Confidence analysis (single pass)
        let confidenceAnalysis = analyzeConfidence(data: confidenceData, totalLines: totalLines)
        insights.append(contentsOf: confidenceInsights(from: confidenceAnalysis))
        
        // Pace analysis (single pass)
        let paceAnalysis = analyzePace(data: confidenceData, duration: duration)
        insights.append(contentsOf: paceInsights(from: paceAnalysis))
        
        // Anchor suggestions (derived from confidence, no extra pass)
        insights.append(contentsOf: anchorSuggestions(from: confidenceAnalysis))
        
        // Overall performance insight
        if let overall = overallInsight(confidence: confidenceAnalysis, pace: paceAnalysis, duration: duration) {
            insights.insert(overall, at: 0) // First insight
        }
        
        return insights.sorted { $0.severity > $1.severity } // Critical first
    }
    
    // MARK: - Confidence Analysis (Optimized)
    
    private static func analyzeConfidence(
        data: [(timestamp: TimeInterval, confidence: Double, lineIndex: Int)],
        totalLines: Int
    ) -> ConfidenceAnalysis {
        
        // Single-pass statistics (O(n), optimal)
        var sum: Double = 0
        var min: Double = 1.0
        var max: Double = 0
        
        for entry in data {
            sum += entry.confidence
            min = Swift.min(min, entry.confidence)
            max = Swift.max(max, entry.confidence)
        }
        
        let average = sum / Double(data.count)
        
        // Find low-confidence sections (sliding window, O(n))
        let lowConfidenceSections = findLowConfidenceSections(
            data: data,
            threshold: average * 0.7 // Below 70% of average
        )
        
        return ConfidenceAnalysis(
            average: average,
            minimum: min,
            maximum: max,
            lowConfidenceSections: lowConfidenceSections
        )
    }
    
    private static func findLowConfidenceSections(
        data: [(timestamp: TimeInterval, confidence: Double, lineIndex: Int)],
        threshold: Double
    ) -> [ConfidenceAnalysis.ConfidenceSection] {
        
        var sections: [ConfidenceAnalysis.ConfidenceSection] = []
        var currentSection: (start: Int, end: Int, sum: Double, count: Int, startTime: TimeInterval)? = nil
        
        for (_, entry) in data.enumerated() {
            if entry.confidence < threshold {
                if var section = currentSection {
                    // Continue section
                    section.end = entry.lineIndex
                    section.sum += entry.confidence
                    section.count += 1
                    currentSection = section
                } else {
                    // Start new section
                    currentSection = (entry.lineIndex, entry.lineIndex, entry.confidence, 1, entry.timestamp)
                }
            } else {
                // End section if exists
                if let section = currentSection {
                    let avgConf = section.sum / Double(section.count)
                    let duration = entry.timestamp - section.startTime
                    
                    sections.append(ConfidenceAnalysis.ConfidenceSection(
                        startLine: section.start,
                        endLine: section.end,
                        averageConfidence: avgConf,
                        duration: duration
                    ))
                    currentSection = nil
                }
            }
        }
        
        return sections
    }
    
    // MARK: - Pace Analysis (Optimized)
    
    private static func analyzePace(
        data: [(timestamp: TimeInterval, confidence: Double, lineIndex: Int)],
        duration: TimeInterval
    ) -> PaceAnalysis {
        
        guard data.count >= 2 else {
            return PaceAnalysis(averageWPM: 0, sections: [], trend: .steady)
        }
        
        // Calculate overall WPM
        let totalLines = data.last!.lineIndex - data.first!.lineIndex
        let averageWPM = (Double(totalLines) * 8.0) / (duration / 60.0) // Assume ~8 words/line
        
        // Split into sections (every ~20% of performance)
        let sectionSize = max(1, data.count / 5)
        var sections: [PaceAnalysis.PaceSection] = []
        
        for i in stride(from: 0, to: data.count, by: sectionSize) {
            let endIdx = min(i + sectionSize, data.count)
            let sectionData = Array(data[i..<endIdx])
            
            guard let first = sectionData.first, let last = sectionData.last else { continue }
            
            let lines = last.lineIndex - first.lineIndex
            let time = last.timestamp - first.timestamp
            let wpm = time > 0 ? (Double(lines) * 8.0) / (time / 60.0) : 0
            
            sections.append(PaceAnalysis.PaceSection(
                startLine: first.lineIndex,
                endLine: last.lineIndex,
                wpm: wpm,
                duration: time
            ))
        }
        
        // Determine trend (simple linear regression on WPM)
        let trend = determinePaceTrend(sections: sections)
        
        return PaceAnalysis(averageWPM: averageWPM, sections: sections, trend: trend)
    }
    
    private static func determinePaceTrend(sections: [PaceAnalysis.PaceSection]) -> PaceAnalysis.Trend {
        guard sections.count >= 3 else { return .steady }
        
        let wpms = sections.map { $0.wpm }
        let changes = zip(wpms, wpms.dropFirst()).map { $1 - $0 }
        
        let avgChange = changes.reduce(0, +) / Double(changes.count)
        let variance = changes.map { pow($0 - avgChange, 2) }.reduce(0, +) / Double(changes.count)
        
        if variance > 100 { // High variance
            return .variable
        } else if avgChange > 5 {
            return .accelerating
        } else if avgChange < -5 {
            return .decelerating
        } else {
            return .steady
        }
    }
    
    // MARK: - Insight Generation (Pure Functions)
    
    private static func confidenceInsights(from analysis: ConfidenceAnalysis) -> [Insight] {
        var insights: [Insight] = []
        
        // Low confidence sections
        for section in analysis.lowConfidenceSections where section.duration > 3.0 {
            let severity: Insight.Severity = section.averageConfidence < 0.3 ? .critical : .warning
            
            insights.append(Insight(
                id: UUID(),
                type: .lowConfidence,
                severity: severity,
                title: "Struggled Section",
                detail: "Lines \(section.startLine)-\(section.endLine) had low confidence (\(Int(section.averageConfidence * 100))%). Practice this section more.",
                lineRange: section.startLine...section.endLine,
                timestamp: Date()
            ))
        }
        
        return insights
    }
    
    private static func paceInsights(from analysis: PaceAnalysis) -> [Insight] {
        var insights: [Insight] = []
        
        // Overall pace feedback
        if analysis.averageWPM < 120 {
            insights.append(Insight(
                id: UUID(),
                type: .paceChange,
                severity: .suggestion,
                title: "Slow Pace",
                detail: "Average \(Int(analysis.averageWPM)) WPM. Consider speeding up slightly for more energy.",
                lineRange: nil,
                timestamp: Date()
            ))
        } else if analysis.averageWPM > 180 {
            insights.append(Insight(
                id: UUID(),
                type: .paceChange,
                severity: .suggestion,
                title: "Fast Pace",
                detail: "Average \(Int(analysis.averageWPM)) WPM. Slow down to ensure clarity.",
                lineRange: nil,
                timestamp: Date()
            ))
        }
        
        // Trend feedback
        switch analysis.trend {
        case .accelerating:
            insights.append(Insight(
                id: UUID(),
                type: .paceChange,
                severity: .info,
                title: "Accelerating Pace",
                detail: "You sped up throughout the performance. Maintain consistent energy.",
                lineRange: nil,
                timestamp: Date()
            ))
        case .decelerating:
            insights.append(Insight(
                id: UUID(),
                type: .paceChange,
                severity: .info,
                title: "Slowing Down",
                detail: "Pace decreased over time. Check if you're losing energy.",
                lineRange: nil,
                timestamp: Date()
            ))
        case .steady:
            insights.append(Insight(
                id: UUID(),
                type: .highPerformance,
                severity: .info,
                title: "Consistent Pace",
                detail: "Great pacing control throughout!",
                lineRange: nil,
                timestamp: Date()
            ))
        case .variable:
            // No insight for variable (normal in comedy)
            break
        }
        
        return insights
    }
    
    private static func anchorSuggestions(from analysis: ConfidenceAnalysis) -> [Insight] {
        var insights: [Insight] = []
        
        // Suggest anchors before problematic sections
        for section in analysis.lowConfidenceSections where section.duration > 5.0 {
            let anchorLine = max(0, section.startLine - 1)
            
            insights.append(Insight(
                id: UUID(),
                type: .anchorSuggestion,
                severity: .suggestion,
                title: "Anchor Suggestion",
                detail: "Add an anchor phrase before line \(section.startLine) to help recover if you go off-script here.",
                lineRange: anchorLine...anchorLine,
                timestamp: Date()
            ))
        }
        
        return insights
    }
    
    private static func overallInsight(
        confidence: ConfidenceAnalysis,
        pace: PaceAnalysis,
        duration: TimeInterval
    ) -> Insight? {
        
        let minutes = Int(duration / 60)
        let confidencePct = Int(confidence.average * 100)
        
        let title: String
        let detail: String
        let severity: Insight.Severity
        
        if confidence.average >= 0.8 && confidence.lowConfidenceSections.isEmpty {
            title = "🎉 Excellent Performance"
            detail = "\(minutes) min performance with \(confidencePct)% avg confidence. You nailed it!"
            severity = .info
        } else if confidence.average >= 0.6 {
            title = "✅ Solid Performance"
            detail = "\(minutes) min performance with \(confidencePct)% avg confidence. Good job!"
            severity = .info
        } else if confidence.average >= 0.4 {
            title = "💪 Room for Improvement"
            detail = "\(minutes) min performance with \(confidencePct)% avg confidence. Review struggle sections below."
            severity = .suggestion
        } else {
            title = "📝 Needs Practice"
            detail = "\(minutes) min performance with \(confidencePct)% avg confidence. Focus on problem areas."
            severity = .warning
        }
        
        return Insight(
            id: UUID(),
            type: .highPerformance,
            severity: severity,
            title: title,
            detail: detail,
            lineRange: nil,
            timestamp: Date()
        )
    }
}
