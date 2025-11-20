import Foundation

/// A simple terminal progress spinner similar to Node.js ora
@MainActor
public class ProgressSpinner {
    private let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var currentFrame = 0
    private var timer: Timer?
    private var message: String
    private let interval: TimeInterval = 0.08

    public init(message: String = "Loading") {
        self.message = message
    }

    public func start() {
        currentFrame = 0
        // Hide cursor
        print("\u{001B}[?25l", terminator: "")
        fflush(stdout)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.render()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    public func update(message: String) {
        self.message = message
    }

    public func succeed(message: String? = nil) {
        stop(symbol: "✓", message: message, color: "\u{001B}[32m")  // Green
    }

    public func fail(message: String? = nil) {
        stop(symbol: "✗", message: message, color: "\u{001B}[31m")  // Red
    }

    public func stop(symbol: String = "", message: String? = nil, color: String = "") {
        timer?.invalidate()
        timer = nil

        // Clear line
        print("\r\u{001B}[K", terminator: "")

        if !symbol.isEmpty {
            let finalMessage = message ?? self.message
            print("\(color)\(symbol)\u{001B}[0m \(finalMessage)")
        }

        // Show cursor
        print("\u{001B}[?25h", terminator: "")
        fflush(stdout)
    }

    private func render() {
        let frame = frames[currentFrame]
        print("\r\u{001B}[36m\(frame)\u{001B}[0m \(message)", terminator: "")
        fflush(stdout)
        currentFrame = (currentFrame + 1) % frames.count
    }
}
