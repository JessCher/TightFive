import SwiftUI
import Combine

enum RunModeDefaultMode: String, CaseIterable, Identifiable {
    case script = "Script"
    case teleprompter = "Teleprompter"
    case cueCard = "Cue Card"
    var id: String { rawValue }
}

enum TeleprompterFontColor: String, CaseIterable, Identifiable {
    case yellow, green, blue, white, red, cyan, purple
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: return TFTheme.yellow
        case .green: return .green
        case .blue: return .blue
        case .white: return .white
        case .red: return .red
        case .cyan: return .cyan
        case .purple: return .purple
        }
    }
}

enum ContextWindowColor: String, CaseIterable, Identifiable {
    case yellow, green, blue, white, red, cyan, black
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: return TFTheme.yellow
        case .green: return .green
        case .blue: return .blue
        case .white: return .white
        case .red: return .red
        case .cyan: return .cyan
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

    @AppStorage("run_autoStartTimer") var autoStartTimer: Bool = false {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("run_autoStartTeleprompter") var autoStartTeleprompter: Bool = false {
        willSet { objectWillChange.send() }
    }

    @AppStorage("run_defaultFontSize") var defaultFontSize: Double = 34 {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("run_defaultSpeed") var defaultSpeed: Double = 40 {
        willSet { objectWillChange.send() }
    }

    @AppStorage("run_scriptFontColor") var scriptFontColorRaw: String = TeleprompterFontColor.white.rawValue {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("run_teleprompterFontColor") var teleprompterFontColorRaw: String = TeleprompterFontColor.white.rawValue {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("run_contextWindowColor") var contextWindowColorRaw: String = ContextWindowColor.yellow.rawValue {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("run_defaultMode") var defaultModeRaw: String = RunModeDefaultMode.script.rawValue {
        willSet { objectWillChange.send() }
    }

    @AppStorage("run_timerColor") var timerColorRaw: String = TimerColor.yellow.rawValue {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("run_timerSize") var timerSize: Double = 32 {
        willSet { objectWillChange.send() }
    }
    
    // MARK: - Cue Card Settings
    
    @AppStorage("cueCard_autoAdvance") var cueCardAutoAdvance: Bool = true {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("cueCard_showPhraseFeedback") var cueCardShowPhraseFeedback: Bool = true {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("cueCard_exitPhraseThreshold") var cueCardExitPhraseThreshold: Double = 0.6 {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("cueCard_fontSize") var cueCardFontSize: Double = 36 {
        willSet { objectWillChange.send() }
    }

    var scriptFontColor: TeleprompterFontColor {
        get { TeleprompterFontColor(rawValue: scriptFontColorRaw) ?? .white }
        set { 
            scriptFontColorRaw = newValue.rawValue
        }
    }

    var teleprompterFontColor: TeleprompterFontColor {
        get { TeleprompterFontColor(rawValue: teleprompterFontColorRaw) ?? .white }
        set { 
            teleprompterFontColorRaw = newValue.rawValue
        }
    }

    var contextWindowColor: ContextWindowColor {
        get { ContextWindowColor(rawValue: contextWindowColorRaw) ?? .yellow }
        set { 
            contextWindowColorRaw = newValue.rawValue
        }
    }

    var defaultMode: RunModeDefaultMode {
        get { RunModeDefaultMode(rawValue: defaultModeRaw) ?? .script }
        set { 
            defaultModeRaw = newValue.rawValue
        }
    }

    var timerColor: TimerColor {
        get { TimerColor(rawValue: timerColorRaw) ?? .yellow }
        set { 
            timerColorRaw = newValue.rawValue
        }
    }
}
