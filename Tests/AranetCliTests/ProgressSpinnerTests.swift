import Foundation
import Testing

@testable import AranetCli

/// Captures the spinner's tick so tests advance frames by hand.
@MainActor
final class FakeTicker {
    private(set) var interval: TimeInterval?
    private(set) var tick: SpinnerTicker.Tick?
    private(set) var cancellations = 0

    var ticker: SpinnerTicker {
        return SpinnerTicker { interval, tick in
            self.interval = interval
            self.tick = tick
            return {
                self.cancellations += 1
            }
        }
    }

    func fire() -> Void {
        self.tick?()
    }
}

@MainActor
@Suite(.tags(.cli))
struct ProgressSpinnerTests {
    private let output = CapturedOutput()
    private let ticker = FakeTicker()

    private func spinner(message: String = "Working") -> ProgressSpinner {
        let output = self.output
        return ProgressSpinner(message: message, write: { output.write($0) }, ticker: self.ticker.ticker)
    }

    @Test("Starting hides the cursor, draws the first frame, and schedules ticks")
    func startDrawsFirstFrame() -> Void {
        let spinner = self.spinner()

        spinner.start()

        #expect(self.output.text == "\u{001B}[?25l\r\u{001B}[36m\u{280B}\u{001B}[0m Working")
        #expect(self.ticker.interval == ProgressSpinner.interval)
        #expect(spinner.isRunning == true)
    }

    @Test("Each tick draws the next frame and wraps around")
    func ticksAdvanceFrames() -> Void {
        let spinner = self.spinner()
        spinner.start()

        for _ in 0 ..< ProgressSpinner.frames.count {
            self.ticker.fire()
        }

        let frames = ProgressSpinner.frames.map { "\r\u{001B}[36m\($0)\u{001B}[0m Working" }
        #expect(self.output.text == "\u{001B}[?25l" + frames.joined() + frames[0])
    }

    @Test("Starting twice does not schedule a second ticker")
    func startIsIdempotent() -> Void {
        let spinner = self.spinner()
        spinner.start()
        let textAfterFirstStart = self.output.text

        spinner.start()

        #expect(self.output.text == textAfterFirstStart)
    }

    @Test("Updating the message changes the next frame")
    func updateMessage() -> Void {
        let spinner = self.spinner()
        spinner.start()

        spinner.update(message: "Still working")
        self.ticker.fire()

        #expect(self.output.text.hasSuffix(" Still working") == true)
    }

    @Test("Succeeding stops the ticker, clears the line, and prints a green check")
    func succeed() -> Void {
        let spinner = self.spinner()
        spinner.start()

        spinner.succeed(message: "Done")

        #expect(self.ticker.cancellations == 1)
        #expect(spinner.isRunning == false)
        #expect(self.output.text.hasSuffix("\r\u{001B}[K\u{001B}[32m\u{2713}\u{001B}[0m Done\n\u{001B}[?25h") == true)
    }

    @Test("Failing prints a red cross with the original message when none is given")
    func fail() -> Void {
        let spinner = self.spinner(message: "Scanning")
        spinner.start()

        spinner.fail()

        #expect(self.output.text.hasSuffix("\r\u{001B}[K\u{001B}[31m\u{2717}\u{001B}[0m Scanning\n\u{001B}[?25h") == true)
    }

    @Test("Stopping without a symbol only clears the line and restores the cursor")
    func stopWithoutSymbol() -> Void {
        let spinner = self.spinner()
        spinner.start()

        spinner.stop()

        #expect(self.output.text.hasSuffix("\r\u{001B}[K\u{001B}[?25h") == true)
        #expect(self.ticker.cancellations == 1)
    }

    @Test("Stopping a spinner that never started still restores the cursor")
    func stopWithoutStart() -> Void {
        let spinner = self.spinner()

        spinner.stop()

        #expect(self.output.text == "\r\u{001B}[K\u{001B}[?25h")
        #expect(self.ticker.cancellations == 0)
    }

    @Test("The default writer is the environment's standard output", .cli())
    func defaultWriterIsEnvironment() throws -> Void {
        let context = try currentContext()
        let spinner = ProgressSpinner(message: "Env", ticker: self.ticker.ticker)

        spinner.render()

        #expect(context.output.text == "\r\u{001B}[36m\u{280B}\u{001B}[0m Env")
    }

    @Test("The live ticker fires on the main run loop until cancelled")
    func liveTickerFires() -> Void {
        let counter = Counter()
        let cancel = SpinnerTicker.live.schedule(every: 0.005) {
            counter.count += 1
        }

        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        cancel()
        let countAfterCancel = counter.count
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        #expect(counter.count > 0)
        #expect(counter.count == countAfterCancel, "No ticks after cancellation")
    }
}
