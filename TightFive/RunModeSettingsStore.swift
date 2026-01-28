import SwiftUI
import Combine

enum RunModeDefaultMode: String, CaseIterable, Identifiable {
    case script = "Script"
    case teleprompter = "Teleprompter"
    var id: String { rawValue }
}

enum TeleprompterFontColor: String, CaseIterable, Identifiable {
    case red, green, yellow, white, cyan
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: return .red
        case .green: return .green
        case .yellow: return TFTheme.yellow
        case .white: return .white
        case .cyan: return .cyan
        }
    }
}

enum ContextWindowColor: String, CaseIterable, Identifiable {
    case yellow, green, blue, black
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: return TFTheme.yellow
        case .green: return .green
        case .blue: return .blue
        case .black: return .black
        }
    }
}

enum TimerColor: String, CaseIterable, Identifiable {
    case red, yellow, blue, green, white
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: return .red
        case .yellow: return TFTheme.yellow
        case .blue: return .blue
        case .green: return .green
        case .white: return .white
        }
    }
}

final class RunModeSettingsStore: ObservableObject {
    static let shared = RunModeSettingsStore()

    @AppStorage("run_autoStartTimer") var autoStartTimer: Bool = false
    @AppStorage("run_autoStartTeleprompter") var autoStartTeleprompter: Bool = false

    @AppStorage("run_defaultFontSize") var defaultFontSize: Double = 34
    @AppStorage("run_defaultSpeed") var defaultSpeed: Double = 40

    @AppStorage("run_scriptFontColor") var scriptFontColorRaw: String = TeleprompterFontColor.white.rawValue
    @AppStorage("run_teleprompterFontColor") var teleprompterFontColorRaw: String = TeleprompterFontColor.white.rawValue
    @AppStorage("run_contextWindowColor") private var contextWindowColorRaw: String = ContextWindowColor.yellow.rawValue
    @AppStorage("run_defaultMode") private var defaultModeRaw: String = RunModeDefaultMode.script.rawValue

    @AppStorage("run_timerColor") var timerColorRaw: String = TimerColor.yellow.rawValue
    @AppStorage("run_timerSize") var timerSize: Double = 32

    var scriptFontColor: TeleprompterFontColor {
        get { TeleprompterFontColor(rawValue: scriptFontColorRaw) ?? .white }
        set { scriptFontColorRaw = newValue.rawValue }
    }

    var teleprompterFontColor: TeleprompterFontColor {
        get { TeleprompterFontColor(rawValue: teleprompterFontColorRaw) ?? .white }
        set { teleprompterFontColorRaw = newValue.rawValue }
    }

    var contextWindowColor: ContextWindowColor {
        get { ContextWindowColor(rawValue: contextWindowColorRaw) ?? .yellow }
        set { contextWindowColorRaw = newValue.rawValue }
    }

    var defaultMode: RunModeDefaultMode {
        get { RunModeDefaultMode(rawValue: defaultModeRaw) ?? .script }
        set { defaultModeRaw = newValue.rawValue }
    }

    var timerColor: TimerColor {
        get { TimerColor(rawValue: timerColorRaw) ?? .yellow }
        set { timerColorRaw = newValue.rawValue }
    }
}
