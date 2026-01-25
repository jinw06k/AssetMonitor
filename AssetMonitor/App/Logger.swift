import Foundation

/// Debug logging utility - only prints in DEBUG builds
enum Logger {
    /// Log a debug message (only in DEBUG builds)
    static func debug(_ message: String, category: String = "App") {
        #if DEBUG
        print("[\(category)] \(message)")
        #endif
    }

    /// Log an error (always prints)
    static func error(_ message: String, category: String = "Error") {
        print("❌ [\(category)] \(message)")
    }

    /// Log a warning (always prints)
    static func warning(_ message: String, category: String = "Warning") {
        print("⚠️ [\(category)] \(message)")
    }
}
