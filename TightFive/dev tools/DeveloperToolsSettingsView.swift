import SwiftUI
import UniformTypeIdentifiers

/// Developer tools settings view for performance monitoring and debugging
struct DeveloperToolsSettingsView: View {
    @State private var monitor = PerformanceMonitor.shared
    @State private var showingExportSheet = false
    @State private var exportedData: String = ""
    @State private var showingClearConfirmation = false
    
    var body: some View {
        Form {
            // Performance Overlay Section
            Section {
                Toggle(isOn: Binding(
                    get: { monitor.isOverlayEnabled },
                    set: { monitor.isOverlayEnabled = $0 }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .foregroundStyle(TFTheme.yellow)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Performance Overlay")
                                .foregroundStyle(.white)
                            Text("Show real-time metrics")
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(TFTheme.yellow)
            } header: {
                Text("Overlay")
            } footer: {
                Text("Display a floating overlay showing CPU usage, memory consumption, FPS, and battery level. Tap to expand for detailed metrics. Drag to reposition.")
            }
            
            // Current Metrics Section
            Section {
                MetricRow(
                    icon: "cpu",
                    label: "CPU Usage",
                    value: String(format: "%.1f%%", monitor.cpuUsage),
                    color: cpuColor
                )
                
                MetricRow(
                    icon: "memorychip",
                    label: "Memory Usage",
                    value: String(format: "%.1f MB", monitor.memoryUsageMB),
                    color: memoryColor
                )
                
                MetricRow(
                    icon: "speedometer",
                    label: "Frame Rate",
                    value: String(format: "%.1f FPS", monitor.currentFPS),
                    color: fpsColor
                )
                
                MetricRow(
                    icon: batteryIcon,
                    label: "Battery Level",
                    value: String(format: "%.0f%%", monitor.batteryLevel) + " " + batteryStateText,
                    color: batteryColor
                )
                
                MetricRow(
                    icon: thermalIcon,
                    label: "Thermal State",
                    value: thermalLabel,
                    color: thermalColor
                )
            } header: {
                Text("Current Metrics")
            } footer: {
                Text("Real-time performance metrics for your device. Metrics update every 0.1 seconds with no throttling. Green indicates good performance, yellow indicates moderate load, and red indicates high load or thermal issues.")
            }
            
            // Active Function Section
            Section {
                HStack {
                    Image(systemName: "function")
                        .foregroundStyle(TFTheme.yellow)
                        .frame(width: 24)
                    
                    Text(monitor.activeFunction)
                        .foregroundStyle(.white)
                        .font(.system(.body, design: .monospaced))
                }
            } header: {
                Text("Active Function")
            } footer: {
                Text("Shows the currently executing tracked function. Use PerformanceMonitor.shared.trackFunction(_:execute:) in your code to track specific operations.")
            }
            
            // Performance Events Section
            Section {
                if monitor.performanceEvents.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("No events recorded yet")
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    ForEach(monitor.performanceEvents.reversed().prefix(20)) { event in
                        EventRow(event: event)
                    }
                    
                    if monitor.performanceEvents.count > 20 {
                        Text("Showing 20 of \(monitor.performanceEvents.count) events")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            } header: {
                HStack {
                    Text("Performance Events")
                    Spacer()
                    Text("\(monitor.performanceEvents.count)")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Recent performance events logged by the app. Events include function executions, view appearances, and custom tracked operations.")
            }
            
            // Actions Section
            Section {
                Button {
                    showingClearConfirmation = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .frame(width: 24)
                        
                        Text("Clear Events")
                            .foregroundStyle(.red)
                    }
                }
                .disabled(monitor.performanceEvents.isEmpty)
                
                Button {
                    exportedData = monitor.exportPerformanceData()
                    showingExportSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(TFTheme.yellow)
                            .frame(width: 24)
                        
                        Text("Export Performance Data")
                            .foregroundStyle(.white)
                    }
                }
                .disabled(monitor.performanceEvents.isEmpty)
            } header: {
                Text("Actions")
            } footer: {
                Text("Export performance data as CSV for analysis in external tools like Excel or Numbers.")
            }
            
            // Developer Information Section
            Section {
                InfoRow(label: "Usage", value: "Track functions in your code")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example:")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Text("""
                    PerformanceMonitor.shared.trackFunction("LoadData") {
                        // Your code here
                    }
                    """)
                    .appFont(.caption)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TFTheme.yellow)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } header: {
                Text("Developer Information")
            } footer: {
                Text("Use the PerformanceMonitor API to track specific functions and operations in your code. Events will appear in the Performance Events section above.")
            }
        }
        .scrollContentBackground(.hidden)
        .tfBackground()
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TFWordmarkTitle(title: "Developer Tools", size: 18)
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ShareSheet(items: [exportedData])
        }
        .alert("Clear All Events?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                monitor.clearEvents()
            }
        } message: {
            Text("This will permanently delete all \(monitor.performanceEvents.count) recorded performance events.")
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
    
    private var batteryStateText: String {
        switch monitor.batteryState {
        case .charging:
            return "(Charging)"
        case .full:
            return "(Full)"
        case .unplugged:
            return ""
        case .unknown:
            return "(Unknown)"
        @unknown default:
            return ""
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
}

// MARK: - Supporting Views

private struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(label)
                .foregroundStyle(.white)
            
            Spacer()
            
            Text(value)
                .foregroundStyle(color)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
        }
    }
}

private struct EventRow: View {
    let event: PerformanceEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: eventIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(eventColor)
                    .frame(width: 20)
                
                Text(event.name)
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if let duration = event.duration {
                    Text(String(format: "%.3fs", duration))
                        .appFont(.caption)
                        .foregroundStyle(durationColor(duration))
                        .font(.system(.caption, design: .monospaced))
                }
            }
            
            HStack(spacing: 12) {
                Label {
                    Text(String(format: "%.1f%%", event.cpuUsage))
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                }
                
                Label {
                    Text(String(format: "%.0f MB", event.memoryUsage))
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "memorychip")
                        .font(.system(size: 10))
                }
                
                Spacer()
                
                Text(event.timestamp, style: .time)
                    .appFont(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
            }
        }
        .padding(.vertical, 4)
    }
    
    private var eventIcon: String {
        switch event.type {
        case .functionExecution:
            return "function"
        case .viewAppearance:
            return "eye"
        case .dataOperation:
            return "internaldrive"
        case .networkRequest:
            return "network"
        case .custom:
            return "star"
        }
    }
    
    private var eventColor: Color {
        switch event.type {
        case .functionExecution:
            return .blue
        case .viewAppearance:
            return .green
        case .dataOperation:
            return .orange
        case .networkRequest:
            return .purple
        case .custom:
            return TFTheme.yellow
        }
    }
    
    private func durationColor(_ duration: TimeInterval) -> Color {
        if duration < 0.1 {
            return .green
        } else if duration < 0.5 {
            return .yellow
        } else {
            return .red
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .foregroundStyle(.white)
        }
    }
}



#Preview {
    NavigationStack {
        DeveloperToolsSettingsView()
    }
    .onAppear {
        // Simulate some data
        PerformanceMonitor.shared.isOverlayEnabled = true
        PerformanceMonitor.shared.logEvent(
            type: .functionExecution,
            name: "LoadBits",
            duration: 0.234,
            cpuUsage: 45.2,
            memoryUsage: 128.5
        )
        PerformanceMonitor.shared.logEvent(
            type: .viewAppearance,
            name: "BitsTabView",
            duration: 0.045,
            cpuUsage: 23.1,
            memoryUsage: 132.8
        )
    }
}
