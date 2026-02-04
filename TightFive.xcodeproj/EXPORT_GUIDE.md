# Performance Data Export Guide

## 📤 Export Options

The performance profiler now supports **4 different export formats**, each optimized for different use cases.

### How to Access Export Menu

1. **Open the performance overlay** - Tap the FPS badge in the top-right corner
2. **Tap the share button** (up arrow icon) in the overlay header
3. **Choose your export format** from the menu

---

## 📊 Export Formats

### 1. CSV File (Detailed Data)
**Best for:** Spreadsheet analysis, charting, deep dive into metrics

**Format:** Standard CSV with headers
```csv
Timestamp,Name,Duration (s),Duration (ms),CPU Start,CPU End,CPU Delta,Memory Start (MB),Memory End (MB),Memory Delta (MB),Severity
2026-02-03T10:30:45Z,"textViewDidChange",0.045,45.23,34.5,57.9,23.4,145.2,148.7,3.5,warning
```

**Columns:**
- `Timestamp` - ISO 8601 formatted date/time
- `Name` - Operation name
- `Duration (s)` - Duration in seconds
- `Duration (ms)` - Duration in milliseconds
- `CPU Start` - CPU usage at start (%)
- `CPU End` - CPU usage at end (%)
- `CPU Delta` - Change in CPU usage (%)
- `Memory Start (MB)` - Memory at start
- `Memory End (MB)` - Memory at end
- `Memory Delta (MB)` - Change in memory
- `Severity` - `normal`, `attention`, `warning`, or `critical`

**Use Cases:**
- Import into Numbers, Excel, or Google Sheets
- Create charts and graphs
- Statistical analysis
- Trend analysis over time

**Tip:** Sort by "Duration (ms)" descending to find slowest operations!

---

### 2. Copy CSV to Clipboard
**Best for:** Quick paste into spreadsheets or documents

**Same format as CSV file, but copies directly to clipboard instead of creating a file.**

**Workflow:**
1. Tap "Copy CSV to Clipboard"
2. You'll feel a haptic feedback confirming the copy
3. Console prints: `✅ CSV data copied to clipboard (X metrics)`
4. Open Numbers/Excel and paste

**Use Cases:**
- Quick analysis without saving files
- Pasting into bug reports
- Sharing in Slack/Discord/Teams

---

### 3. JSON File (Machine-Readable)
**Best for:** Programmatic analysis, automation, archiving

**Format:** Pretty-printed JSON with complete metadata
```json
{
  "currentCPU": 45.6,
  "currentFPS": 58.5,
  "currentMemoryMB": 156.8,
  "exportDate": "2026-02-03T10:30:45Z",
  "metrics": [
    {
      "cpuDelta": 23.4,
      "cpuEnd": 57.9,
      "cpuStart": 34.5,
      "duration": 0.045,
      "durationMs": 45.23,
      "memoryDeltaMB": 3.5,
      "memoryEndMB": 148.7,
      "memoryStartMB": 145.2,
      "name": "textViewDidChange",
      "severity": "warning",
      "timestamp": "2026-02-03T10:30:45Z"
    }
  ],
  "totalMetrics": 42
}
```

**Use Cases:**
- Processing with Python/JavaScript scripts
- Automated performance regression testing
- Long-term archival (structured format)
- Integration with monitoring systems

**Example Python Analysis:**
```python
import json
import pandas as pd

with open('performance-2026-02-03-103045.json') as f:
    data = json.load(f)

df = pd.DataFrame(data['metrics'])
print(f"Average duration: {df['durationMs'].mean():.2f}ms")
print(f"Slowest operation: {df.loc[df['durationMs'].idxmax(), 'name']}")
```

---

### 4. Summary Report (Human-Readable)
**Best for:** Quick overview, sharing with team, bug reports

**Format:** Plain text report with statistics and recommendations
```
PERFORMANCE SUMMARY REPORT
Generated: Tuesday, February 3, 2026 at 10:30:45 AM PST
======================================================================

📊 CURRENT METRICS
----------------------------------------------------------------------
FPS:        58.5 fps
CPU Usage:  45.6%
Memory:     156.8 MB

📈 STATISTICS
----------------------------------------------------------------------
Total Operations:    42
Slow Operations:     8
Critical Operations: 2

Average Duration:    12.34 ms
Max Duration:        234.56 ms
Min Duration:        0.45 ms

🐌 TOP 10 SLOWEST OPERATIONS
----------------------------------------------------------------------
 1. 🔴 ModelContainer Creation                 - 234.56 ms
 2. 🟠 textViewDidChange                       - 45.23 ms
 3. 🟡 Widget Theme Sync                       - 23.45 ms
 ...

🔁 MOST FREQUENT OPERATIONS
----------------------------------------------------------------------
 1. textViewDidChange (×156)
 2. scheduleToolbarUpdate (×142)
 3. commitNow (×89)
 ...

🔥 HIGHEST CPU IMPACT OPERATIONS
----------------------------------------------------------------------
 1. textViewDidChange                          (+23.4% CPU)
 2. Background Canvas Render                   (+18.7% CPU)
 ...

💡 RECOMMENDATIONS
----------------------------------------------------------------------
• WARNING: FPS is below 55. UI may feel slightly laggy.
• CRITICAL: CPU usage over 100%. Device will heat up and drain battery.
• ATTENTION: 2 operations took over 500ms. These need optimization.

======================================================================
End of Report
```

**Use Cases:**
- Quick status check
- Sharing findings with your team
- Including in bug reports
- Documentation for performance work

**What It Shows:**
- **Current Metrics:** Real-time FPS, CPU, memory
- **Statistics:** Count of operations, averages, min/max
- **Top 10 Slowest:** Operations that took the longest
- **Most Frequent:** What's being called repeatedly
- **Highest CPU Impact:** What's using the most CPU
- **Recommendations:** Actionable advice based on your metrics

---

## 🎯 Which Format to Use?

| Scenario | Best Format |
|----------|-------------|
| Need to analyze trends | **CSV** |
| Quick paste into spreadsheet | **Copy to Clipboard** |
| Automated testing/scripts | **JSON** |
| Share with team/bug report | **Summary Report** |
| Deep dive with Python/R | **JSON** or **CSV** |
| First-time performance check | **Summary Report** |

---

## 📱 Sharing the Files

All file exports use iOS's standard share sheet, so you can:
- **Save to Files** - Store locally or in iCloud
- **AirDrop** - Send to your Mac instantly
- **Share to Mail** - Email to yourself or team
- **Share to Messages** - Send to colleagues
- **Copy** - Copy the file to paste elsewhere
- **Save to Notes** - Archive in Apple Notes
- **Third-party apps** - Dropbox, Google Drive, Slack, etc.

---

## 🔬 Example Analysis Workflows

### Workflow 1: Finding the Slowest Operation
1. Use app and trigger slow behavior
2. Export **CSV file**
3. Open in Numbers/Excel
4. Sort by "Duration (ms)" descending
5. Top row is your bottleneck!

### Workflow 2: Tracking Performance Over Time
1. Before optimization: Export **JSON** → save as `before.json`
2. Apply your fixes
3. After optimization: Export **JSON** → save as `after.json`
4. Write a script to compare the two
5. Prove your optimization worked!

### Workflow 3: Bug Report
1. Reproduce the issue
2. Export **Summary Report**
3. Copy text and paste into bug report
4. Also attach **CSV** for detailed data
5. Team can see exact performance impact

### Workflow 4: Automated Testing
1. Add performance tests to your CI/CD
2. Export **JSON** during test runs
3. Parse JSON and check thresholds:
   - Fail if any operation > 100ms
   - Fail if average FPS < 55
   - Fail if CPU usage > 80%
4. Catch performance regressions before shipping!

---

## 💡 Pro Tips

### Tip 1: Export Regularly
Export data **before** and **after** each optimization to prove it worked!

### Tip 2: Share With Others
If someone on your team reports slowness, have them:
1. Reproduce the issue
2. Export Summary Report
3. Send it to you
4. You can see exactly what's slow

### Tip 3: Archive for Comparison
Save exports with version numbers:
```
performance-v1.0-baseline.json
performance-v1.1-after-background-fix.json
performance-v1.2-after-text-editor-fix.json
```

### Tip 4: Focus on "Critical" and "Warning"
In the CSV/JSON, filter by severity:
- **Critical** (>500ms) - Must fix
- **Warning** (100-500ms) - Should fix
- **Attention** (16-100ms) - Consider fixing if frequent
- **Normal** (<16ms) - No action needed

### Tip 5: Look at Frequency × Duration
An operation that takes 20ms but happens 1000 times is worse than one that takes 100ms but happens once!

---

## 🛠 Technical Details

### File Locations
All exported files are created in the iOS temporary directory:
```
FileManager.default.temporaryDirectory
```

Files are automatically cleaned up by iOS when:
- Your app terminates
- iOS needs to free up space
- A few days have passed

**Important:** Save exported files somewhere permanent if you need to keep them!

### File Naming Convention
Files include timestamps for easy sorting:
```
performance-2026-02-03-103045.csv
performance-2026-02-03-103045.json
performance-summary-2026-02-03-103045.txt
```

Format: `yyyy-MM-dd-HHmmss`

### iPad Considerations
On iPad, the share sheet appears as a popover centered on the screen. All export options work identically to iPhone.

---

## 🐛 Troubleshooting

### "Nothing happens when I tap Export"
**Check console for error messages:**
- `❌ Failed to export CSV: ...`
- `❌ Failed to export JSON: ...`
- `❌ Failed to export summary: ...`

**Common causes:**
- Disk full (unlikely but possible)
- Permissions issue (rare on iOS)

### "Share sheet doesn't appear"
**Solution:** Ensure the performance overlay is visible. The share button only appears in the expanded overlay.

### "CSV has weird formatting"
**Solution:** Make sure you're opening with a proper spreadsheet app (Numbers, Excel). Don't open in TextEdit or Notes - use the proper tool!

### "JSON won't parse"
**Solution:** The JSON is valid and pretty-printed. If a parser rejects it, check if the file was corrupted during transfer. Try exporting again.

---

## 📞 Getting Help

If you're seeing unexpected performance issues:

1. **Export Summary Report** - Get the overview
2. **Export CSV** - Get the detailed data
3. **Check console** - Look for "⚠️ SLOW:" messages
4. **Share both files** - Makes debugging easier

The profiler is designed to tell you exactly what's slow. Trust the data! 📊
