import Foundation
import SwiftUI
import SwiftData

/// Emergency data recovery utility to check for recoverable data
@MainActor
class DataRecoveryUtility: ObservableObject {
    
    @Published var recoveryStatus: String = "Checking..."
    @Published var foundItems: [RecoveryItem] = []
    
    struct RecoveryItem: Identifiable {
        let id = UUID()
        let type: ItemType
        let location: String
        let size: Int64?
        let modifiedDate: Date?
        
        enum ItemType {
            case audioFile
            case database
            case backup
            case iCloudFile
        }
        
        var displayName: String {
            switch type {
            case .audioFile:
                return "🎤 Audio Recording"
            case .database:
                return "💾 Database File"
            case .backup:
                return "📦 Backup File"
            case .iCloudFile:
                return "☁️ iCloud File"
            }
        }
    }
    
    func scanForRecoverableData() {
        foundItems = []
        recoveryStatus = "Scanning for recoverable data..."
        
        // 1. Check local recordings directory
        scanLocalRecordings()
        
        // 2. Check iCloud recordings
        scanICloudRecordings()
        
        // 3. Check for database files
        scanDatabaseFiles()
        
        // 4. Check documents directory
        scanDocumentsDirectory()
        
        if foundItems.isEmpty {
            recoveryStatus = "❌ No recoverable data found"
        } else {
            recoveryStatus = "✅ Found \(foundItems.count) potentially recoverable items"
        }
    }
    
    private func scanLocalRecordings() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsURL = documentsURL.appendingPathComponent("Recordings")
        
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: recordingsURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("❌ Could not access local recordings directory")
            return
        }
        
        for file in files {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            
            foundItems.append(RecoveryItem(
                type: .audioFile,
                location: file.lastPathComponent,
                size: size.map { Int64($0) },
                modifiedDate: date
            ))
            
            print("✅ Found local recording: \(file.lastPathComponent)")
        }
    }
    
    private func scanICloudRecordings() {
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("Recordings") else {
            print("⚠️ iCloud not available")
            return
        }
        
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: iCloudURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("❌ Could not access iCloud recordings directory")
            return
        }
        
        for file in files {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            
            foundItems.append(RecoveryItem(
                type: .iCloudFile,
                location: file.lastPathComponent,
                size: size.map { Int64($0) },
                modifiedDate: date
            ))
            
            print("✅ Found iCloud recording: \(file.lastPathComponent)")
        }
    }
    
    private func scanDatabaseFiles() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: appSupport,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: []
        ) else {
            print("❌ Could not access application support directory")
            return
        }
        
        for file in files {
            let filename = file.lastPathComponent
            if filename.hasSuffix(".store") || filename.hasSuffix(".sqlite") || filename.contains("default") {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                
                foundItems.append(RecoveryItem(
                    type: .database,
                    location: file.path,
                    size: size.map { Int64($0) },
                    modifiedDate: date
                ))
                
                print("✅ Found database file: \(filename)")
            }
        }
    }
    
    private func scanDocumentsDirectory() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: []
        ) else {
            return
        }
        
        for file in files {
            let filename = file.lastPathComponent
            // Look for any backup or data files
            if filename.contains("backup") || filename.contains("export") {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
                let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                
                foundItems.append(RecoveryItem(
                    type: .backup,
                    location: file.path,
                    size: size.map { Int64($0) },
                    modifiedDate: date
                ))
                
                print("✅ Found backup file: \(filename)")
            }
        }
    }
    
    func printAllDirectories() {
        print("\n📂 === ALL DIRECTORIES ===")
        
        let fileManager = FileManager.default
        
        // Documents
        if let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            print("\n📁 Documents: \(docsURL.path)")
            printDirectoryContents(docsURL, recursive: true)
        }
        
        // Application Support
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            print("\n📁 Application Support: \(appSupportURL.path)")
            printDirectoryContents(appSupportURL, recursive: true)
        }
        
        // Caches
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            print("\n📁 Caches: \(cachesURL.path)")
            printDirectoryContents(cachesURL, recursive: false)
        }
        
        // iCloud
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            print("\n☁️ iCloud Container: \(iCloudURL.path)")
            printDirectoryContents(iCloudURL, recursive: true)
        }
        
        print("\n📂 === END OF DIRECTORIES ===\n")
    }
    
    private func printDirectoryContents(_ url: URL, recursive: Bool, depth: Int = 0) {
        let indent = String(repeating: "  ", count: depth)
        
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: []
        ) else {
            print("\(indent)⚠️ Could not read directory")
            return
        }
        
        for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let size = (try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let date = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            
            let dateStr = date.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? "unknown"
            
            if isDirectory {
                print("\(indent)📁 \(item.lastPathComponent)/")
                if recursive && depth < 3 {
                    printDirectoryContents(item, recursive: true, depth: depth + 1)
                }
            } else {
                let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                print("\(indent)📄 \(item.lastPathComponent) (\(sizeStr), \(dateStr))")
            }
        }
    }
}

// MARK: - Recovery View

struct DataRecoveryView: View {
    @StateObject private var recovery = DataRecoveryUtility()
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(recovery.recoveryStatus)
                        .appFont(.body)
                        .foregroundStyle(recovery.foundItems.isEmpty ? .red : .green)
                }
                
                if !recovery.foundItems.isEmpty {
                    Section("Found Items") {
                        ForEach(recovery.foundItems) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.displayName)
                                        .appFont(.body, weight: .semibold)
                                    Spacer()
                                    if let size = item.size {
                                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                            .appFont(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Text(item.location)
                                    .appFont(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                
                                if let date = item.modifiedDate {
                                    Text("Modified: \(date, style: .relative) ago")
                                        .appFont(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section {
                    Button("Scan for Recoverable Data") {
                        recovery.scanForRecoverableData()
                    }
                    
                    Button("Print All Directories (Console)") {
                        recovery.printAllDirectories()
                    }
                }
            }
            .navigationTitle("Data Recovery")
            .onAppear {
                recovery.scanForRecoverableData()
                recovery.printAllDirectories()
            }
        }
    }
}

#Preview {
    DataRecoveryView()
}
