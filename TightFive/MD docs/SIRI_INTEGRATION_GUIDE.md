# Siri Integration for TightFive

This document explains how to set up and use Siri commands in TightFive to create bits using voice dictation.

## Overview

Users can now say things like:
- **"Siri, write a quick bit"**
- **"Hey Siri, create a bit with TightFive"**
- **"Add a new bit to TightFive"**

Siri will then ask: "What would you like your bit to be about?" and the user can dictate the content.

## Files Created

### 1. `WriteQuickBitIntent.swift`
The main App Intent that handles creating a bit via Siri. This intent:
- Receives dictated text from the user
- Optionally accepts a title
- Creates a new `Bit` in SwiftData
- Returns a confirmation dialog and visual snippet

### 2. `TightFiveAppShortcuts.swift`
Registers the app shortcuts with the system. This tells iOS about available Siri commands and their trigger phrases.

## Setup Required

### Step 1: Add to Your Xcode Project

1. Add both `WriteQuickBitIntent.swift` and `TightFiveAppShortcuts.swift` to your Xcode project
2. Make sure they're included in your app target (not just the widget extension)

### Step 2: Update Info.plist (If Needed)

App Intents are automatically discovered by the system, but you may want to add a privacy description:

```xml
<key>NSSiriUsageDescription</key>
<string>TightFive uses Siri to help you quickly capture comedy bits using voice dictation.</string>
```

### Step 3: Build and Run

1. Build and run your app on a device (Siri shortcuts don't work well in Simulator)
2. The first time the app runs with the new intents, iOS will register them with Siri

### Step 4: Test with Siri

Say to Siri:
- "Write a quick bit in TightFive"
- "Create a bit with TightFive"

Siri should respond with: "What would you like your bit to be about?"

Then dictate your bit content, and Siri will create it and show you a confirmation.

## How It Works

### User Flow

1. **User invokes Siri**: "Hey Siri, write a quick bit"
2. **Siri prompts for content**: "What would you like your bit to be about?"
3. **User dictates**: "So I was at the grocery store yesterday and noticed that the self-checkout machines now have an attitude..."
4. **System creates bit**: The intent creates a new `Bit` with the dictated text
5. **Siri confirms**: "I've created your bit: 'So I was at the grocery store...' with 18 words."
6. **Visual snippet shown**: A nice card showing the created bit

### Code Flow

```swift
WriteQuickBitIntent.perform() ->
  1. Creates ModelContainer for Bit
  2. Validates content is not empty
  3. Creates new Bit(text: content, status: .loose)
  4. Saves to SwiftData
  5. Returns success dialog + snippet view
```

## Customization Options

### Add More Shortcuts

You can add more shortcuts to `TightFiveAppShortcuts.swift`:

```swift
static var appShortcuts: [AppShortcut] {
    AppShortcut(
        intent: WriteQuickBitIntent(),
        phrases: [
            "Write a quick bit in \(.applicationName)",
            // Add more phrases here
            "Capture a comedy bit in \(.applicationName)",
            "Save a joke to \(.applicationName)"
        ],
        shortTitle: "Write Quick Bit",
        systemImageName: "mic.fill"
    )
}
```

### Add Optional Title Parameter

The intent already supports an optional title. Users can say:
- "Write a quick bit called 'Grocery Store Saga' in TightFive"

And Siri will prompt for the content.

### Customize the Snippet View

Edit `BitCreatedSnippetView` in `WriteQuickBitIntent.swift` to customize the confirmation card:

```swift
struct BitCreatedSnippetView: View {
    let bitTitle: String
    let content: String
    let wordCount: Int
    
    var body: some View {
        // Customize this view to match your app's design
        VStack(alignment: .leading, spacing: 12) {
            // Your custom UI here
        }
        .padding()
    }
}
```

## Important Note: Single AppShortcutsProvider

⚠️ **Only one `AppShortcutsProvider` conformance is allowed per app.** All app shortcuts must be registered in a single provider struct.

In TightFive, all shortcuts are registered in `TightFiveAppShortcuts.swift`. If you need to add more shortcuts, add them to the array in that file.

## Troubleshooting

### Error: Multiple AppShortcutsProvider conformances

If you see: `Only 1 'AppIntents.AppShortcutsProvider' conformance is allowed per app`

**Solution**: Remove any other structs conforming to `AppShortcutsProvider` and consolidate all shortcuts into `TightFiveAppShortcuts.swift`.

### Siri doesn't recognize the command

1. Make sure you've built and run the app at least once on the device
2. Try saying the exact phrases defined in `TightFiveAppShortcuts`
3. Check Settings > Siri & Search > [Your App] to see if shortcuts are listed
4. Sometimes it takes a few minutes for iOS to index new intents

### Bits aren't being created

1. Check that your SwiftData model schema matches the `Bit` model
2. Verify the ModelContainer is being created successfully
3. Look for error logs in Xcode console
4. Make sure the app has proper data permissions

### Snippet view doesn't show

1. The snippet view is optional and may not show on all devices/contexts
2. Make sure your view conforms to `View` protocol correctly
3. Try simplifying the view if it's too complex

## Future Enhancements

You could add more intents for:

1. **Start Practice Session**: "Siri, start practice in TightFive"
2. **Add Bit to Setlist**: "Siri, add bit to my weekend show setlist"
3. **Mark Bit as Finished**: "Siri, mark my last bit as finished"
4. **Search Bits**: "Siri, find bits about grocery stores in TightFive"

Each would be a separate intent file following the same pattern as `WriteQuickBitIntent.swift`.

## Notes

- **Privacy**: App Intents run in a sandboxed environment and don't send data to Apple servers
- **Offline**: The intent works offline (though Siri itself requires connectivity)
- **Model Access**: The intent creates its own ModelContext from your app's container
- **Thread Safety**: SwiftData handles thread safety automatically with ModelContext

## Related Documentation

- [App Intents Framework](https://developer.apple.com/documentation/AppIntents)
- [Creating App Shortcuts](https://developer.apple.com/documentation/AppIntents/creating-app-shortcuts)
- [SwiftData with App Intents](https://developer.apple.com/documentation/SwiftData)
