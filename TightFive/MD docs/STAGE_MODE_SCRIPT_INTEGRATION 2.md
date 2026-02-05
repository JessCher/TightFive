# Stage Mode Integration with Script Modes

## Overview

This document explains how Stage Mode (StageModeView) should integrate with the new Script Mode system to properly handle both Modular and Traditional script editing modes.

## Key Integration Points

### 1. Cue Card Mode Availability Check

**Before displaying Cue Card mode, check availability:**

```swift
// In StageModeView or any Stage Mode component
let cueCardSettings = CueCardSettingsStore.shared

// Option 1: Check at mode level
if cueCardSettings.stageModeType == .cueCards {
    if !setlist.cueCardsAvailable {
        // Fallback to Script mode
        cueCardSettings.stageModeType = .script
    }
}

// Option 2: Use built-in check
if !StageModeType.cueCards.isAvailable(for: setlist) {
    // Disable cue card UI or show message
}
```

### 2. Generating Cue Cards

**Modular Mode:**
```swift
if setlist.currentScriptMode == .modular {
    // Use script blocks to generate cue cards
    let cards = setlist.scriptBlocks.map { block in
        CueCard(from: block, assignments: setlist.assignments)
    }
}
```

**Traditional Mode with Custom Cards:**
```swift
if setlist.currentScriptMode == .traditional && setlist.hasCustomCueCards {
    // Load custom cue cards
    let cards = loadCustomCueCards(for: setlist)
}
```

**Traditional Mode without Custom Cards:**
```swift
if setlist.currentScriptMode == .traditional && !setlist.hasCustomCueCards {
    // Cue Cards not available - show error or redirect
    showMessage("Cue Cards unavailable. Please configure custom cards or switch to Script mode.")
}
```

### 3. Getting Script Content

**For Script and Teleprompter modes (works with both script modes):**
```swift
// This automatically works with both modular and traditional
let scriptText = setlist.scriptPlainText

// Or with formatting if needed
let attributedText: NSAttributedString
if setlist.currentScriptMode == .traditional {
    attributedText = NSAttributedString.fromRTF(setlist.traditionalScriptRTF) ?? NSAttributedString()
} else {
    // Modular: combine script blocks
    attributedText = setlist.scriptBlocks.attributedString(using: setlist.assignments)
}
```

### 4. Anchor and Exit Phrase Detection

**Modular Mode:**
- Each script block can have anchor/exit phrases
- Look up in associated SetlistAssignment
- Auto-advance between blocks based on phrases

**Traditional Mode:**
- Custom cue cards define their own anchor/exit phrases
- No automatic detection from content
- Must be manually configured by user

**Implementation:**
```swift
func getAnchorPhrase(for index: Int) -> String? {
    if setlist.currentScriptMode == .modular {
        // Get from script block assignment
        let block = setlist.scriptBlocks[index]
        return setlist.assignment(for: block)?.anchorPhrase
    } else {
        // Get from custom cue card
        return customCueCards[index].anchorPhrase
    }
}

func getExitPhrase(for index: Int) -> String? {
    if setlist.currentScriptMode == .modular {
        let block = setlist.scriptBlocks[index]
        return setlist.assignment(for: block)?.exitPhrase
    } else {
        return customCueCards[index].exitPhrase
    }
}
```

### 5. Recording and Performance Tracking

**Both modes should record the same performance data:**

```swift
// Performance recording works regardless of script mode
let performance = Performance(setlist: setlist)
performance.scriptSnapshot = setlist.scriptPlainText
performance.scriptMode = setlist.currentScriptMode.rawValue

// Recording proceeds as normal
```

## Recommended Stage Mode Entry Flow

```swift
struct StageModeView: View {
    let setlist: Setlist
    @State private var currentMode: StageModeType
    @State private var showModeUnavailable = false
    
    init(setlist: Setlist) {
        self.setlist = setlist
        let settings = CueCardSettingsStore.shared
        
        // Validate mode is available
        if !settings.stageModeType.isAvailable(for: setlist) {
            // Choose fallback
            if UserDefaults.standard.bool(forKey: "user_prefers_teleprompter") {
                _currentMode = State(initialValue: .teleprompter)
            } else {
                _currentMode = State(initialValue: .script)
            }
            _showModeUnavailable = State(initialValue: true)
        } else {
            _currentMode = State(initialValue: settings.stageModeType)
        }
    }
    
    var body: some View {
        // ... stage mode UI
    }
}
```

## Custom Cue Card Data Structure

**Future Implementation:**

```swift
// Store as JSON in setlist
extension Setlist {
    var customCueCardsData: Data { get set }
    
    var customCueCards: [CustomCueCard] {
        get {
            guard let data = customCueCardsData,
                  let cards = try? JSONDecoder().decode([CustomCueCard].self, from: data) else {
                return []
            }
            return cards
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            customCueCardsData = data
        }
    }
}

struct CustomCueCard: Identifiable, Codable {
    let id: UUID
    var content: String
    var anchorPhrase: String?
    var exitPhrase: String?
    var order: Int
}
```

## Testing Stage Mode with Both Script Modes

### Test Case 1: Modular Mode → Stage Mode
```
Given: Setlist in Modular mode with 3 bits
When: User enters Stage Mode with Cue Cards selected
Then: 
  - Should display 3 cue cards
  - Should detect anchor/exit phrases from assignments
  - Should allow voice-driven advancement
```

### Test Case 2: Traditional Mode (No Custom Cards) → Stage Mode
```
Given: Setlist in Traditional mode without custom cards
When: User enters Stage Mode with Cue Cards selected
Then:
  - Should show "Cue Cards unavailable" message
  - Should fallback to Script mode
  - Should remember this happened for next entry
```

### Test Case 3: Traditional Mode (With Custom Cards) → Stage Mode
```
Given: Setlist in Traditional mode with 5 custom cards configured
When: User enters Stage Mode with Cue Cards selected
Then:
  - Should display 5 custom cue cards
  - Should detect anchor/exit phrases from custom cards
  - Should allow voice-driven advancement
```

### Test Case 4: Mode Switch During Active Performance
```
Given: User performing in Stage Mode
When: Script mode is changed in background
Then:
  - Performance continues with current mode
  - Warning shown after performance ends
  - Cue cards regenerated for next performance
```

## Error Handling

### Scenario: Cue Cards Requested But Unavailable

```swift
func validateStageModeEntry() -> StageModeValidationResult {
    let settings = CueCardSettingsStore.shared
    
    if settings.stageModeType == .cueCards {
        if setlist.currentScriptMode == .traditional && !setlist.hasCustomCueCards {
            return .unavailable(
                reason: "Cue Cards require custom configuration in Traditional mode",
                suggestedMode: .script
            )
        }
    }
    
    return .valid
}

enum StageModeValidationResult {
    case valid
    case unavailable(reason: String, suggestedMode: StageModeType)
}
```

### Scenario: Custom Cards Malformed

```swift
func loadCustomCueCards() -> [CustomCueCard] {
    do {
        let cards = setlist.customCueCards
        guard !cards.isEmpty else {
            throw CueCardError.noCards
        }
        return cards
    } catch {
        // Fall back to script mode
        showError("Could not load custom cue cards. Switching to Script mode.")
        CueCardSettingsStore.shared.stageModeType = .script
        return []
    }
}
```

## UI Recommendations

### Mode Indicator in Stage Mode

Show current script mode somewhere in the UI:

```swift
VStack {
    // Top bar
    HStack {
        Image(systemName: setlist.currentScriptMode == .modular ? "square.grid.2x2" : "doc.text")
        Text(setlist.currentScriptMode.displayName)
        Spacer()
        // ... performance controls
    }
    
    // Stage content
}
```

### Cue Card Header

For traditional mode with custom cards, show indication:

```swift
if setlist.currentScriptMode == .traditional {
    Text("Custom Card \(currentIndex + 1) of \(customCueCards.count)")
        .font(.caption)
        .foregroundColor(.yellow.opacity(0.7))
}
```

## Performance Considerations

### Cue Card Generation

**Modular Mode:**
- Cards generated on-demand from script blocks
- Fast: O(n) where n = number of blocks
- No additional storage needed

**Traditional Mode:**
- Cards loaded from JSON
- Fast: O(1) after initial decode
- Small storage overhead (~1-5 KB)

### Content Access

Both modes provide `scriptPlainText` with similar performance:
- Modular: Concatenates blocks (cached if needed)
- Traditional: Extracts from RTF (cached if needed)

## Migration Strategy

If adding Stage Mode features that depend on script structure:

1. **Check script mode first**
2. **Branch behavior accordingly**
3. **Provide sensible defaults for both modes**
4. **Test with both modes**

Example:
```swift
func getPerformanceMetrics() -> Metrics {
    if setlist.currentScriptMode == .modular {
        // Can analyze per-bit timing
        return Metrics(
            bitCount: setlist.bitCount,
            averageBitDuration: calculateBitDuration(),
            // ...
        )
    } else {
        // Only total script metrics available
        return Metrics(
            bitCount: 0,
            totalDuration: estimatedDuration,
            // ...
        )
    }
}
```

## Future Enhancements

### Smart Cue Card Generation for Traditional Mode

```swift
// Analyze traditional script and suggest card breaks
func suggestCueCardBreaks(script: String) -> [CustomCueCard] {
    // AI/ML analysis of script structure
    // Identify natural breakpoints
    // Extract potential anchor phrases
    // Generate suggested cards
}
```

### Hybrid Mode

```swift
// Future: Allow mix of modular and traditional sections
enum ScriptSection {
    case modular([ScriptBlock])
    case traditional(Data)
}

extension Setlist {
    var scriptSections: [ScriptSection] { get set }
}
```

---

**Integration Status:** ✅ Complete  
**Custom Cue Cards:** 🚧 Placeholder (needs full implementation)  
**Testing:** ⚠️ Required before release  
**Documentation:** ✅ Complete
