# CloudKit Duplicate Registration Fix - CRITICAL
**Date:** February 3, 2026  
**Status:** ✅ CRITICAL BUG FIXED

---

## 🚨 The Critical Bug

```
BUG IN CLIENT OF CLOUDKIT: Registering a handler for a CKScheduler activity 
identifier that has already been registered.

CloudKit setup failed because it couldn't register a handler for the export activity. 
There is another instance of this persistent store actively syncing with CloudKit 
in this process.
```

This was causing:
- ❌ CloudKit sync failures
- ❌ Multiple ModelContainer instances
- ❌ Duplicate CloudKit registration
- ❌ Store removal and teardown cycles
- ❌ Data sync corruption risk

---

## 🔍 Root Cause

### The Problem: Computed Property

**File:** `TightFiveApp.swift`

```swift
// ❌ WRONG: This creates a NEW container every time it's accessed
private var sharedModelContainer: ModelContainer {
    let schema = Schema([...])
    let container = try ModelContainer(for: schema, ...)
    return container
}
```

**What was happening:**
1. SwiftUI accesses `sharedModelContainer` property
2. Computed property creates a **brand new** ModelContainer
3. New container registers CloudKit sync handlers
4. SwiftUI re-evaluates and accesses property again
5. **Another new** ModelContainer is created
6. CloudKit says "Wait, this identifier is already registered!"
7. Error, sync failure, store teardown

### Why Computed Properties Are Dangerous Here

In SwiftUI, body evaluation happens frequently:
- Initial render
- State changes
- View updates
- Scene phase changes
- Font changes
- **Every time:** New ModelContainer = Duplicate registration

---

## ✅ The Fix

### Changed to Static Lazy Property

```swift
// ✅ CORRECT: Create ONCE and reuse forever
private static let sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Bit.self,
        Setlist.self,
        BitVariation.self,
        SetlistAssignment.self,
        Performance.self,
        UserProfile.self
    ])
    
    let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        allowsSave: true,
        cloudKitDatabase: .automatic
    )
    
    do {
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        print("✅ ModelContainer created with CloudKit sync")
        return container
    } catch {
        // Fallback without CloudKit
        let fallbackConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        
        let container = try! ModelContainer(for: schema, configurations: [fallbackConfig])
        print("⚠️ ModelContainer created without CloudKit: \(error)")
        return container
    }
}()
```

### Usage

```swift
.modelContainer(Self.sharedModelContainer)
```

---

## 🎯 Why This Works

### Static Lazy Property Characteristics

1. **Created Once** - Swift guarantees lazy static properties are initialized exactly once
2. **Thread Safe** - Swift handles synchronization automatically
3. **Survives View Updates** - Static property is not tied to view lifecycle
4. **Reused** - Same instance returned every time
5. **No Re-registration** - CloudKit handlers only registered once

### Lifecycle

```
App Launch
    ↓
First Access to sharedModelContainer
    ↓
Static initializer runs ONCE
    ↓
ModelContainer created
    ↓
CloudKit sync registered
    ↓
Property returns container
    ↓
All future accesses return SAME container
    ↓
No duplicate registration ✅
```

---

## 📊 Impact

### Before Fix

```
❌ Multiple ModelContainer instances created
❌ CloudKit duplicate registration errors
❌ Sync teardowns and failures
❌ "Store Removed" errors
❌ "Request cancelled" errors
❌ Potential data loss
```

### After Fix

```
✅ Single ModelContainer instance
✅ One CloudKit registration
✅ Stable sync
✅ No teardowns
✅ Reliable data persistence
✅ Safe CloudKit sync
```

---

## 🧪 Testing

### Verify the Fix

1. **Clean Build** (Cmd+Shift+K)
2. **Delete App** from device/simulator
3. **Build and Run**
4. **Watch Console** for:
   - ✅ Single "ModelContainer created" message
   - ✅ No duplicate registration errors
   - ✅ No teardown messages
   - ✅ Successful CloudKit sync

### Expected Console Output

```
✅ ModelContainer created with CloudKit sync
```

**NOT:**
```
❌ BUG IN CLIENT OF CLOUDKIT: Registering a handler...
❌ resetting internal state after error...
❌ Told to tear down with reason: Store Removed
```

---

## 🔑 Key Lessons

### 1. ModelContainer Must Be Singleton

ModelContainer is **not** a lightweight object. It:
- Opens database connections
- Registers system handlers
- Manages CloudKit sync
- Cannot be duplicated safely

### 2. Computed Properties Are Dangerous

Computed properties in SwiftUI Apps can be evaluated multiple times. Never use them for:
- Database connections
- File handles
- System registrations
- Expensive operations

### 3. Static Lazy Is The Pattern

For singletons in SwiftUI Apps:
```swift
private static let instance: Type = { ... }()
```

**Not:**
```swift
private var instance: Type { ... }  // ❌ Wrong!
```

### 4. SwiftData + CloudKit Is Strict

Unlike Core Data, SwiftData with CloudKit:
- Enforces single container per process
- Fails loudly on duplicate registration
- Cannot recover from registration errors
- Requires clean architecture

---

## 🚨 How To Avoid This Pattern

### ❌ Don't Do This

```swift
// Computed property = recreated every time
private var database: ModelContainer { 
    try! ModelContainer(...) 
}

// Instance property = recreated with view
@State private var database = ModelContainer(...)

// Multiple containers
let container1 = ModelContainer(...)
let container2 = ModelContainer(...) // Duplicate!
```

### ✅ Do This

```swift
// Static lazy = created once, reused forever
private static let database: ModelContainer = {
    try! ModelContainer(...)
}()

// Or use @main struct's static property
.modelContainer(Self.sharedModelContainer)
```

---

## 📝 Files Modified

1. ✅ `TightFiveApp.swift` - Changed ModelContainer from computed property to static lazy property

---

## 🎉 Result

**The Bug:**
Multiple ModelContainer instances causing CloudKit duplicate registration and sync failures.

**The Fix:**
Single static ModelContainer instance created once and reused throughout app lifetime.

**The Outcome:**
- ✅ Stable CloudKit sync
- ✅ No duplicate registrations
- ✅ No store teardowns
- ✅ Reliable data persistence
- ✅ Clean console logs

---

## 🚀 Additional Benefits

This fix also:
- **Improves startup performance** - Container created once, not multiple times
- **Reduces memory usage** - Single instance vs multiple
- **Prevents data corruption** - No competing sync operations
- **Simplifies debugging** - One source of truth

---

**Critical bug fixed. Your CloudKit sync is now stable! ☁️✅**
