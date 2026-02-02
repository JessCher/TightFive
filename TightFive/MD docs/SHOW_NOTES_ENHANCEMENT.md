# Show Notes Enhancement - Implementation Summary

## Overview
Enhanced the Show Notes feature to provide detailed bit-by-bit performance analysis with flippable cards, individual bit ratings/notes, and a dual rating system.

## Key Features Implemented

### 1. Flippable Script Block Cards
- **File**: `FlippableScriptBlockCard.swift`
- Each bit/freeform block in the setlist now displays as a flippable card
- **Front**: Shows the bit content (same as before)
- **Back**: Shows rating input (1-5 stars) and notes section for that specific bit
- Uses the exact same flip animation as the existing Bits & Bit Notes feature (`FlippableBitCard`)
- Flip button in bottom-right corner with visual indicator if rated or has notes

### 2. Dual Rating System
- **"How it went"** (Auto-calculated)
  - Automatically calculated as the average of all individual bit ratings
  - Displayed with a chart icon (📊)
  - Read-only - updates as you rate individual bits
  - Shows "Rate bits above" prompt when no bits are rated yet

- **"How it felt"** (Manual)
  - Your overall subjective feeling about the performance
  - Displayed with a heart icon (❤️)
  - Fully editable 1-5 star rating
  - Independent of bit ratings

### 3. Individual Bit Ratings & Notes
- Each script block (bit or freeform) can have:
  - **Star rating** (1-5 stars, tap to rate/unrate)
  - **Notes section** with TextEditor for detailed thoughts
- Data stored per script block ID in the Performance model
- Persists across sessions and syncs immediately

### 4. Performance List Updates
- Performance rows now show both ratings when available:
  - Chart icon + stars for calculated rating
  - Heart icon + stars for manual rating
- Compact vertical layout in the row

### 5. Overall Show Notes
- Renamed to "Overall Show Notes" to clarify distinction from bit notes
- Added subtitle: "General thoughts about the performance"
- For capturing overall performance impressions, venue notes, audience observations, etc.

## Data Model Changes

### Performance.swift
Added the following properties to the `Performance` model:

```swift
/// Dictionary of bit ratings by script block ID (1-5 stars)
@Attribute(.externalStorage) var bitRatings: [String: Int] = [:]

/// Dictionary of bit notes by script block ID
@Attribute(.externalStorage) var bitNotes: [String: String] = [:]

/// Auto-calculated "How it went" rating based on bit ratings
var calculatedRating: Int {
    let ratings = bitRatings.values.filter { $0 > 0 }
    guard !ratings.isEmpty else { return 0 }
    let sum = ratings.reduce(0, +)
    return Int(round(Double(sum) / Double(ratings.count)))
}
```

- `bitRatings` and `bitNotes` use `.externalStorage` attribute for efficient large data storage
- Keys are script block UUID strings for unique identification
- `calculatedRating` is a computed property that auto-updates

## UI/UX Flow

1. **Open Show Notes** → Tap a performance
2. **View Setlist Section** → Shows scrollable list of flippable script blocks
3. **Tap any block** → Front shows bit content with flip button
4. **Tap flip button** → Card flips to show rating stars and notes input
5. **Rate the bit** → Tap stars to rate (1-5, tap again to unrate)
6. **Add notes** → Tap notes field to add thoughts about that specific bit
7. **Flip back** → Tap flip button to return to content view
8. **Scroll through all bits** → Rate and annotate each one
9. **View ratings** → "How it went" auto-calculates from your bit ratings
10. **Set overall feeling** → Rate "How it felt" manually
11. **Add show notes** → Write overall thoughts in the notes section

## Design Consistency

- Uses existing `FlippableBitCard` component for consistent animation
- Matches existing `BitFlipButton` styling
- Yellow indicator dot shows when card has rating or notes
- Icon changes on front: star.fill when rated, note.text otherwise
- All styling consistent with TFTheme and existing dynamic cards
- Same 3D rotation effect with spring animation

## Benefits

1. **Detailed Feedback Loop**: Capture what worked and what didn't for each bit
2. **Pattern Recognition**: Over multiple shows, see which bits consistently perform well
3. **Material Refinement**: Track specific notes on delivery, timing, punchline variations
4. **Objective vs Subjective**: Separate data-driven performance from personal feeling
5. **Historical Record**: Build a comprehensive performance history for each bit
6. **Preparation**: Review previous notes before performing bits again

## Technical Notes

- SwiftData automatically persists changes
- Dictionary keys are UUID strings for Codable compliance
- Calculated rating rounds to nearest integer
- Empty dictionaries by default (no storage overhead for unrated performances)
- All state management uses `@Bindable` and proper SwiftUI patterns
- Flip state tracked per card with Set<UUID> for efficient lookups

## Future Enhancements (Optional)

- Analytics view showing bit performance trends over time
- Export detailed performance reports
- Compare "how it went" vs "how it felt" across shows
- Bit heatmap showing which bits get highest ratings
- Smart suggestions based on historical data
