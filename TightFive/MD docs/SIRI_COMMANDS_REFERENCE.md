# Siri Commands Quick Reference

## Available Commands

### Write a Quick Bit

Create a new comedy bit using voice dictation.

**Trigger Phrases:**
- "Write a quick bit in TightFive"
- "Create a bit with TightFive"
- "Add a new bit to TightFive"
- "TightFive write a bit"

**Example Interaction:**

```
User: "Hey Siri, write a quick bit"

Siri: "What would you like your bit to be about?"

User: "So I was at the airport security line, and the TSA agent 
       looked at my ID and said 'you look different in the photo'
       and I was like 'yeah, in the photo I had hope for humanity'"

Siri: "I've created your bit: 'So I was at the airport security 
       line...' with 39 words."
       
[Shows snippet card with bit preview]
```

### With Optional Title

You can also provide a title for your bit:

```
User: "Hey Siri, write a quick bit"

Siri: "What would you like your bit to be about?"

User: "My joke about airport security"

Siri: "I've created your bit: 'My joke about airport security' 
       with 5 words."
```

## What Happens Behind the Scenes

1. **Siri receives your voice command** - Processes the trigger phrase
2. **Intent is invoked** - `WriteQuickBitIntent` starts executing
3. **Siri prompts for content** - Asks what your bit should be about
4. **You dictate your bit** - Siri transcribes your speech to text
5. **Bit is created** - New `Bit` object saved to SwiftData as `.loose` status
6. **Confirmation shown** - Dialog + visual card confirms creation
7. **Open your app** - Go to "Loose Ideas" to see your new bit

## Tips for Best Results

### Be Specific
The clearer your dictation, the better the transcription.

### Natural Speech
Speak naturally - Siri handles punctuation automatically (though not perfectly).

### Review in App
After creating a bit via Siri, open TightFive to:
- Edit the text
- Add tags
- Add notes
- Fix any transcription errors

### Quick Capture
This is designed for capturing ideas quickly. You can polish them later in the app.

## Advantages Over Manual Entry

✅ **Hands-free** - Create bits while driving, cooking, or walking
✅ **Speed** - Faster than opening app and typing
✅ **Capture fleeting ideas** - Don't let funny thoughts escape
✅ **Natural flow** - Speak your bit as you'd perform it
✅ **No app launch needed** - Works from anywhere

## Limitations

⚠️ **Siri requires internet** - For speech recognition (though the app itself works offline)
⚠️ **Transcription accuracy** - May need editing for punctuation/formatting
⚠️ **No rich text** - Creates plain text bits only
⚠️ **Limited metadata** - Can't set tags, notes, or other fields via Siri

## Integration with Existing Features

### Created bits are:
- ✅ Saved as "Loose" status
- ✅ Visible in "Loose Ideas" tab
- ✅ Fully editable in the app
- ✅ Can be added to setlists
- ✅ Can be marked as finished
- ✅ Can have tags, notes, and variations added

### Does NOT interfere with:
- ✅ QuickBit widget
- ✅ Manual bit creation
- ✅ Existing bits or setlists
- ✅ Any other app functionality

## Privacy & Security

🔒 **On-device processing** - Bit creation happens locally on your device
🔒 **No Apple servers** - Your comedy material stays in your app
🔒 **Siri transcription** - Speech-to-text happens via Siri (standard privacy applies)
🔒 **No sharing** - Bits are never shared with third parties

## Future Possibilities

We could add more Siri commands for:
- Starting practice sessions
- Adding bits to specific setlists
- Searching your bit library
- Getting performance stats
- And more...

Let me know if you'd like to add any of these!
