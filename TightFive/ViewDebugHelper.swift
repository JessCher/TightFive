import SwiftUI

/// Helper to identify views that are re-rendering excessively
struct ViewDebugModifier: ViewModifier {
    let viewName: String
    @State private var renderCount = 0
    
    func body(content: Content) -> some View {
        let _ = {
            renderCount += 1
            // Only print if excessive (more than 10 renders)
            if renderCount > 10 && renderCount % 10 == 0 {
                print("⚠️ WARNING: \(viewName) has rendered \(renderCount) times")
            }
        }()
        
        return content
    }
}

extension View {
    func debugRenders(_ viewName: String) -> some View {
        #if DEBUG
        return self.modifier(ViewDebugModifier(viewName: viewName))
        #else
        return self
        #endif
    }
}
