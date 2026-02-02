# Script Mode System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          SETLIST MODEL                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Properties:                                                    │
│  • scriptMode: String                                           │
│  • scriptBlocksData: Data (for Modular)                        │
│  • traditionalScriptRTF: Data (for Traditional)                │
│  • hasCustomCueCards: Bool                                      │
│  • assignments: [SetlistAssignment]                             │
│                                                                 │
│  Computed:                                                      │
│  • currentScriptMode: ScriptMode (.modular/.traditional)       │
│  • cueCardsAvailable: Bool                                      │
│  • scriptPlainText: String (mode-aware)                        │
│  • hasScriptContent: Bool (mode-aware)                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │
            ┌───────────────┴────────────────┐
            │                                │
            ▼                                ▼
┌──────────────────────┐        ┌──────────────────────┐
│   MODULAR MODE       │        │  TRADITIONAL MODE    │
├──────────────────────┤        ├──────────────────────┤
│                      │        │                      │
│  Content:            │        │  Content:            │
│  • Script Blocks     │        │  • Single RTF Doc    │
│  • Assignments       │        │  • Continuous Text   │
│                      │        │                      │
│  Features:           │        │  Features:           │
│  ✅ Insert Bits      │        │  ✅ Rich Text Edit   │
│  ✅ Freeform Text    │        │  ✅ Full Formatting  │
│  ✅ Drag & Drop      │        │  ✅ Bold/Italic      │
│  ✅ Reorder          │        │  ✅ Colors/Fonts     │
│  ✅ Variations       │        │  ❌ Bit Blocks       │
│                      │        │  ❌ Variations       │
│  Cue Cards:          │        │                      │
│  ✅ Auto-Generated   │        │  Cue Cards:          │
│     from blocks      │        │  ⚠️  Custom Config   │
│                      │        │     Required         │
│  Stage Mode:         │        │                      │
│  ✅ All Modes OK     │        │  Stage Mode:         │
│                      │        │  ✅ Script           │
│                      │        │  ✅ Teleprompter     │
│                      │        │  ⚠️  Cue Cards*      │
│                      │        │     (*if configured) │
└──────────────────────┘        └──────────────────────┘
            │                                │
            │                                │
            └────────────────┬───────────────┘
                            │
                            ▼
            ┌───────────────────────────────┐
            │   STAGE MODE INTEGRATION      │
            ├───────────────────────────────┤
            │                               │
            │  Query: setlist.              │
            │         cueCardsAvailable     │
            │                               │
            │  Decision Tree:               │
            │  ┌─────────────────────────┐  │
            │  │ if .modular:            │  │
            │  │   → Use script blocks   │  │
            │  │   → Auto cue cards      │  │
            │  │                         │  │
            │  │ if .traditional:        │  │
            │  │   if hasCustomCueCards: │  │
            │  │     → Use custom cards  │  │
            │  │   else:                 │  │
            │  │     → Disable cue cards │  │
            │  │     → Default to Script │  │
            │  └─────────────────────────┘  │
            │                               │
            └───────────────────────────────┘
                            │
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  CUE CARDS   │    │   SCRIPT     │    │ TELEPROMPTER │
├──────────────┤    ├──────────────┤    ├──────────────┤
│              │    │              │    │              │
│ Modular:     │    │ Both Modes:  │    │ Both Modes:  │
│ ✅ Available │    │ ✅ Available │    │ ✅ Available │
│              │    │              │    │              │
│ Traditional: │    │ Uses:        │    │ Uses:        │
│ ⚠️  Conditional│   │ • scriptPlain│    │ • scriptPlain│
│    (custom)  │    │   Text       │    │   Text       │
│              │    │ • Scrollable │    │ • Auto-scroll│
└──────────────┘    └──────────────┘    └──────────────┘
```

## Mode Switching Flow

```
[Modular Mode]
      │
      │ User selects Traditional
      ▼
┌────────────────────────────────┐
│ Show Confirmation Dialog       │
│ "Cue cards will be disabled    │
│  until you configure custom    │
│  cards. Continue?"             │
└────────────────────────────────┘
      │ Confirm
      ▼
┌────────────────────────────────┐
│ 1. Copy script blocks to RTF   │
│ 2. Set mode = .traditional     │
│ 3. Disable cue cards           │
│ 4. Set Stage default = Script  │
│ 5. Update timestamp            │
└────────────────────────────────┘
      │
      ▼
[Traditional Mode]
      │
      │ User configures custom cards
      ▼
┌────────────────────────────────┐
│ Custom Cue Card Editor         │
│ • Create cards                 │
│ • Set anchor/exit phrases      │
│ • Save configuration           │
└────────────────────────────────┘
      │
      ▼
┌────────────────────────────────┐
│ Set hasCustomCueCards = true   │
│ Enable cue cards in Stage Mode │
└────────────────────────────────┘
```

## Data Flow for Stage Mode

```
┌─────────────────────────────────────────────────┐
│              User Opens Stage Mode              │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│  Load CueCardSettingsStore.shared.stageModeType │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│  Check: stageModeType.isAvailable(for: setlist) │
└─────────────────────────────────────────────────┘
         │                                │
         │ Available                      │ Unavailable
         ▼                                ▼
┌──────────────────┐          ┌────────────────────┐
│ Load Stage Mode  │          │ Show Warning       │
│ with selected    │          │ Fallback to Script │
│ type             │          │ or Teleprompter    │
└──────────────────┘          └────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│              Generate Stage Content             │
├─────────────────────────────────────────────────┤
│                                                 │
│  if CUE CARDS:                                  │
│    if modular:                                  │
│      → Generate from scriptBlocks               │
│    else if traditional && hasCustomCueCards:    │
│      → Load customCueCards                      │
│                                                 │
│  if SCRIPT or TELEPROMPTER:                     │
│    → Load setlist.scriptPlainText               │
│                                                 │
└─────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│            Display Stage Mode UI                │
└─────────────────────────────────────────────────┘
```

## Custom Cue Card Data Structure

```
┌─────────────────────────────────────────────────┐
│                  CustomCueCard                  │
├─────────────────────────────────────────────────┤
│  id: UUID                                       │
│  content: String        (The card text)        │
│  anchorPhrase: String?  (Voice recognition)    │
│  exitPhrase: String?    (Auto-advance trigger) │
│  order: Int             (Display sequence)     │
└─────────────────────────────────────────────────┘
                      │
                      │ Stored as JSON array
                      ▼
┌─────────────────────────────────────────────────┐
│         Setlist.customCueCardsData: Data        │
│ (Future: could be separate SwiftData model)    │
└─────────────────────────────────────────────────┘
```

## UI Component Hierarchy

```
SetlistBuilderView
├── titleField
├── tabPicker [Script | Notes]
├── scriptEditor (mode-aware)
│   ├── scriptModeBanner
│   │   ├── Mode Icon + Name
│   │   └── "Change Mode" button → showScriptModeSettings
│   │
│   ├── if modular:
│   │   ├── modularScriptEditor
│   │   │   ├── scriptEmptyState (if empty)
│   │   │   ├── scriptBlockList (if has blocks)
│   │   │   └── addContentFAB
│   │
│   └── if traditional:
│       └── traditionalScriptEditor
│           ├── Info banner
│           └── RichTextEditor (rtfData: traditionalScriptRTF)
│
├── notesEditor (unchanged)
│   └── RichTextEditor (rtfData: notesRTF)
│
└── toolbar
    ├── Done button
    ├── Run Mode button (if hasScriptContent)
    └── Menu
        ├── Stage Mode (if hasScriptContent)
        ├── if modular: "Configure Anchors"
        ├── if traditional: "Configure Cue Cards"
        ├── Stage Mode Settings
        ├── Script Mode → showScriptModeSettings ⭐
        ├── Status (Draft/Finished)
        ├── Export/Duplicate/Copy
        └── Delete

Sheets:
├── .sheet(showScriptModeSettings)
│   └── ScriptModeSettingsView
│       ├── Mode picker
│       ├── Feature comparison
│       ├── Switch confirmation alert
│       └── Mode change logic
│
├── .sheet(showCustomCueCardEditor)
│   └── CustomCueCardEditorView
│       ├── Empty state (if no cards)
│       ├── Card list (if has cards)
│       └── Add/Edit card UI (placeholder)
│
├── .sheet(showCueCardSettings)
│   └── CueCardSettingsView(setlist: setlist)
│       ├── Stage Mode Type picker
│       ├── if cueCards && available:
│       │   ├── Auto-advance settings
│       │   ├── Display settings
│       │   └── Animation settings
│       └── if cueCards && unavailable:
│           └── cueCardsUnavailableView
│
└── Other existing sheets...
```

## State Management

```
╔══════════════════════════════════════════════════╗
║              PERSISTENT STATE                    ║
║              (SwiftData)                         ║
╠══════════════════════════════════════════════════╣
║  Setlist:                                        ║
║  • scriptMode: String                            ║
║  • scriptBlocksData: Data                        ║
║  • traditionalScriptRTF: Data                    ║
║  • hasCustomCueCards: Bool                       ║
║  • customCueCardsData: Data (future)             ║
╚══════════════════════════════════════════════════╝
                      │
                      │ reads/writes
                      ▼
╔══════════════════════════════════════════════════╗
║              USER PREFERENCES                    ║
║              (UserDefaults)                      ║
╠══════════════════════════════════════════════════╣
║  • user_prefers_teleprompter: Bool               ║
║  • cueCard_stageModeType: String                 ║
║  • cueCard_fontSize: Double                      ║
║  • ... (other stage mode settings)               ║
╚══════════════════════════════════════════════════╝
                      │
                      │ accessed by
                      ▼
╔══════════════════════════════════════════════════╗
║              RUNTIME STATE                       ║
║              (@State, @Observable)               ║
╠══════════════════════════════════════════════════╣
║  SetlistBuilderView:                             ║
║  • showScriptModeSettings: Bool                  ║
║  • showCustomCueCardEditor: Bool                 ║
║  • editingBlockId: UUID?                         ║
║                                                  ║
║  CueCardSettingsStore (shared):                  ║
║  • stageModeType: StageModeType                  ║
║  • autoAdvanceEnabled: Bool                      ║
║  • ... (other settings)                          ║
╚══════════════════════════════════════════════════╝
```

## Decision Points for Feature Development

When adding features that interact with scripts:

```
[New Feature Idea]
      │
      ▼
┌────────────────────────────────┐
│ Does it require knowing        │
│ script structure?              │
└────────────────────────────────┘
      │                  │
      │ YES              │ NO
      ▼                  ▼
┌────────────────┐  ┌────────────────┐
│ Branch by mode │  │ Use scriptPlain│
│                │  │ Text directly  │
│ if modular:    │  │ Works with both│
│   • Use blocks │  └────────────────┘
│   • Detailed   │
│                │
│ if traditional:│
│   • Estimate   │
│   • Approximate│
└────────────────┘
      │
      ▼
┌────────────────────────────────┐
│ Implement both code paths      │
│ Test with both modes           │
│ Document mode differences      │
└────────────────────────────────┘
```

---

**Diagram Version:** 1.0  
**Last Updated:** February 1, 2026  
**Status:** Complete
