import Foundation
import os

/// Collects everything a command writes to one output stream; safe to call from any task.
final class CapturedOutput: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: "")

    var text: String {
        return self.storage.withLock { $0 }
    }

    /// The captured text split into lines, without a trailing empty line.
    var lines: [String] {
        var lines = self.text.components(separatedBy: "\n")
        if lines.last == "" {
            lines.removeLast()
        }
        return lines
    }

    func write(_ text: String) -> Void {
        self.storage.withLock { $0 += text }
    }

    func contains(_ fragment: String) -> Bool {
        return self.text.contains(fragment)
    }
}
