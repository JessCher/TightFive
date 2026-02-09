import SwiftUI
import UIKit


/// Temporary helper view to discover your device identifier
/// Add this to your app temporarily to get your device ID, then remove it
struct DeviceIdentifierHelper: View {
    @State private var showCopiedAlert = false
    
    private var currentDeviceIdentifier: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Device Identifier Helper")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Use this identifier in DeveloperAccessControl.swift")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Device ID:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                
                Text(currentDeviceIdentifier)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .textSelection(.enabled)
            }
            .padding()
            .background(Color("TFCard"))
            .cornerRadius(12)
            
            Button {
                UIPasteboard.general.string = currentDeviceIdentifier
                showCopiedAlert = true
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc.fill")
                    Text("Copy to Clipboard")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color("TFYellow"))
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Instructions:")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("1. Copy the device ID above")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                
                Text("2. Open DeveloperAccessControl.swift")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                
                Text("3. Replace YOUR-DEVICE-IDENTIFIER-HERE with your copied ID")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                
                Text("4. Remove this helper view from your app")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding()
            .background(Color("TFCard").opacity(0.5))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            TFBackground()
        }
        .alert("Copied!", isPresented: $showCopiedAlert) {
            Button("OK") { }
        } message: {
            Text("Device identifier copied to clipboard")
        }
    }
}

#Preview {
    DeviceIdentifierHelper()
}
