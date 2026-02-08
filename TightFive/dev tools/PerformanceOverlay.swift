import SwiftUI
import UIKit

/// Floating performance overlay that displays real-time metrics
struct PerformanceOverlay: View {
    @State private var monitor = PerformanceMonitor.shared
    @State private var position: CGPoint = CGPoint(x: UIScreen.main.bounds.width - 100, y: 100)
    @State private var isExpanded: Bool = false
    @State private var isDragging: Bool = false
    
    private let compactSize: CGSize = CGSize(width: 100, height: 130)
    private let expandedSize: CGSize = CGSize(width: 280, height: 230)
    
    var body: some View {
        ZStack {
            if monitor.isOverlayEnabled {
                Group {
                    if isExpanded {
                        expandedView
                    } else {
                        compactView
                    }
                }
                .position(position)
                .gesture(dragGesture)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: position)
                .drawingGroup() // Rasterize to reduce SwiftUI overhead
            }
        }
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        VStack(spacing: 6) {
            // CPU indicator
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(cpuColor)
                Text(String(format: "%.0f%%", monitor.cpuUsage))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(cpuColor)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Memory indicator
            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(memoryColor)
                Text(String(format: "%.0f", monitor.memoryUsageMB))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(memoryColor)
                Text("MB")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(memoryColor.opacity(0.7))
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // FPS indicator
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(fpsColor)
                Text(String(format: "%.0f", monitor.currentFPS))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(fpsColor)
                Text("FPS")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(fpsColor.opacity(0.7))
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Thermal indicator
            HStack(spacing: 4) {
                Image(systemName: thermalIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(thermalColor)
                Text(thermalLabel)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(thermalColor)
            }
        }
        .padding(10)
        .frame(width: compactSize.width, height: compactSize.height)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onTapGesture {
            isExpanded = true
        }
    }
    
    // MARK: - Expanded View
    
    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Performance")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    isExpanded = false
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Metrics
            VStack(alignment: .leading, spacing: 8) {
                metricRow(
                    icon: "cpu",
                    label: "CPU",
                    value: String(format: "%.1f%%", monitor.cpuUsage),
                    color: cpuColor,
                    progress: monitor.cpuUsage / 100.0
                )
                
                metricRow(
                    icon: "memorychip",
                    label: "Memory",
                    value: String(format: "%.0f MB", monitor.memoryUsageMB),
                    color: memoryColor,
                    progress: min(monitor.memoryUsageMB / 512.0, 1.0) // Normalize to 512MB
                )
                
                metricRow(
                    icon: "speedometer",
                    label: "FPS",
                    value: String(format: "%.1f", monitor.currentFPS),
                    color: fpsColor,
                    progress: monitor.currentFPS / 60.0
                )
                
                metricRow(
                    icon: batteryIcon,
                    label: "Battery",
                    value: String(format: "%.0f%%", monitor.batteryLevel),
                    color: batteryColor,
                    progress: monitor.batteryLevel / 100.0
                )
                
                metricRow(
                    icon: thermalIcon,
                    label: "Thermal",
                    value: thermalLabel,
                    color: thermalColor,
                    progress: thermalProgress
                )
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Active function
            HStack(spacing: 6) {
                Image(systemName: "function")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text(monitor.activeFunction)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(12)
        .frame(width: expandedSize.width)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Helper Views
    
    private func metricRow(icon: String, label: String, value: String, color: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 16)
                
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: geometry.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 4)
        }
    }
    
    // MARK: - Computed Properties
    
    private var cpuColor: Color {
        if monitor.cpuUsage < 30 {
            return .green
        } else if monitor.cpuUsage < 60 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var memoryColor: Color {
        if monitor.memoryUsageMB < 200 {
            return .green
        } else if monitor.memoryUsageMB < 400 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var fpsColor: Color {
        if monitor.currentFPS > 50 {
            return .green
        } else if monitor.currentFPS > 30 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var batteryColor: Color {
        if monitor.batteryLevel > 50 {
            return .green
        } else if monitor.batteryLevel > 20 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var batteryIcon: String {
        switch monitor.batteryState {
        case .charging, .full:
            return "battery.100.bolt"
        case .unplugged:
            if monitor.batteryLevel > 75 {
                return "battery.100"
            } else if monitor.batteryLevel > 50 {
                return "battery.75"
            } else if monitor.batteryLevel > 25 {
                return "battery.50"
            } else {
                return "battery.25"
            }
        default:
            return "battery.100"
        }
    }
    
    private var thermalColor: Color {
        switch monitor.thermalState {
        case .nominal:
            return .green
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        @unknown default:
            return .gray
        }
    }
    
    private var thermalIcon: String {
        switch monitor.thermalState {
        case .nominal:
            return "thermometer.low"
        case .fair:
            return "thermometer.medium"
        case .serious:
            return "thermometer.high"
        case .critical:
            return "exclamationmark.triangle.fill"
        @unknown default:
            return "thermometer"
        }
    }
    
    private var thermalLabel: String {
        switch monitor.thermalState {
        case .nominal:
            return "Normal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "CRITICAL"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var thermalProgress: Double {
        switch monitor.thermalState {
        case .nominal:
            return 0.25
        case .fair:
            return 0.5
        case .serious:
            return 0.75
        case .critical:
            return 1.0
        @unknown default:
            return 0.0
        }
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                isDragging = true
                
                // Keep within bounds
                let screenBounds = UIScreen.main.bounds
                let size = isExpanded ? expandedSize : compactSize
                let halfWidth = size.width / 2
                let halfHeight = size.height / 2
                
                position = CGPoint(
                    x: min(max(value.location.x, halfWidth + 20), screenBounds.width - halfWidth - 20),
                    y: min(max(value.location.y, halfHeight + 60), screenBounds.height - halfHeight - 100)
                )
            }
            .onEnded { _ in
                isDragging = false
                
                // Snap to nearest edge
                let screenWidth = UIScreen.main.bounds.width
                let threshold = screenWidth / 2
                
                if position.x < threshold {
                    position.x = (isExpanded ? expandedSize.width : compactSize.width) / 2 + 20
                } else {
                    position.x = screenWidth - (isExpanded ? expandedSize.width : compactSize.width) / 2 - 20
                }
            }
    }
}
// MARK: - View Extension

extension View {
    /// Adds a performance monitoring overlay to the view hierarchy
    func performanceOverlay() -> some View {
        self.overlay(alignment: .topTrailing) {
            if DeveloperAccessControl.canAccessDevTools {
                PerformanceOverlay()
            }
        }
    }
}
