# Performance Insights Implementation

## Overview
This implementation connects Show Notes ratings and notes back to individual bits in Finished Bits, allowing comedians to track how each bit performs across multiple shows.

## Key Features

### 1. **Insights Button in Finished Bit Detail**
- A new "Performance Insights" button appears below the "Compare Variations" button
- Shows a count badge indicating how many performances have data for this bit
- Opens the Performance Insights view when tapped

### 2. **Performance Insights View**
The insights view displays:

#### Average Rating Header
- Shows the average rating across all performances
- Displays rating as stars (1-5 scale) with half-star support
- Shows total number of performances
- Only appears if the bit has been rated at least once

#### Individual Performance Cards
Each card shows:
- **Date performed** (formatted as date)
- **Venue name** (if provided)
- **City** (if provided)  
- **Star rating** (1-5 stars)
- **Notes** (the specific notes about how this bit performed)
- **Show reference** (which show note the data came from)

### 3. **Data Connection**
The system works by:
1. Fetching all Performance records from Show Notes
2. For each performance, loading its associated Setlist
3. Finding ScriptBlocks that reference the specific Bit
4. Extracting ratings and notes stored in the Performance's `bitRatings` and `bitNotes` dictionaries
5. Combining this with performance metadata (date, venue, city)

### 4. **Important Distinction**
- **Show Notes ratings/notes**: These are performance-specific feedback stored per ScriptBlock ID
- **Bit Notes**: These are general notes about the bit itself (separate feature in Finished/Loose Bits)
- These two types of notes are completely independent and serve different purposes

## Technical Implementation

### New Components Added

#### `BitPerformanceInsightsButton`
- A button component that displays the insights count
- Fetches insight count on appear
- Opens the insights sheet

#### `BitPerformanceInsightsView`
- Main view displaying all insights
- Calculates average rating
- Shows empty state when no data exists
- Sorted by date (newest first)

#### `PerformanceInsightCard`
- Individual card component for each performance
- Displays venue, date, city, rating, and notes
- Styled consistently with the app's design system

#### `BitPerformanceInsight`
- View model struct representing a single performance instance
- Contains all display data for one performance
- Includes static `fetchInsights()` method that:
  - Queries all performances
  - Filters for performances containing this bit
  - Extracts ratings and notes
  - Returns sorted array of insights

## User Experience

### Empty State
When a bit has never been rated in Show Notes:
- Shows a chart icon
- "No Performance Data Yet" message
- Helpful text explaining to rate bits in Show Notes

### With Data
When performances exist:
1. Average rating card at top (if rated)
2. List of performance cards below
3. Each card shows where and when the bit was performed
4. Notes from that specific performance

### Example Flow
1. Comedian performs a set in "Stage Mode" (creates a Performance)
2. In Show Notes, they rate each bit and add notes about performance
3. Later, in Finished Bits, they tap "Performance Insights" on a bit
4. They see all past performances with ratings/notes
5. They can track improvement over time and identify which venues/audiences responded best

## Code Location
All new code is in `FinishedBitsView.swift` at the bottom:
- `BitPerformanceInsightsButton` struct
- `BitPerformanceInsightsView` struct  
- `PerformanceInsightCard` struct
- `BitPerformanceInsight` struct with `fetchInsights()` method

## Dependencies
Requires these existing models:
- `Bit` - The bit model
- `Performance` - Show notes performance records
- `Setlist` - Setlist containing script blocks
- `ScriptBlock` - Individual blocks in a setlist (bits or freeform)
- `SetlistAssignment` - Bit snapshots referenced by script blocks
- `ModelContext` - SwiftData context for queries

## Future Enhancements
Potential additions:
- Charts/graphs showing rating trends over time
- Filter by venue or date range
- Export performance history
- Compare performance across different bits
- Venue/audience type analysis
