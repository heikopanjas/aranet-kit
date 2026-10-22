import AranetKit
import Foundation
import Testing

@testable import AranetCli

/// The fakes behind one test's `CliEnvironment`, reachable through the `current` task-local.
final class CliTestContext: Sendable {
    @TaskLocal static var current: CliTestContext?

    let client: FakeSensorClient
    let output = CapturedOutput()
    let errorOutput = CapturedOutput()
    let interrupts: AsyncStream<Void>
    let interrupt: AsyncStream<Void>.Continuation
    let isTerminal: Bool
    let arguments: [String]
    let now: Date

    @MainActor
    init(isTerminal: Bool, arguments: [String], now: Date) {
        self.client = FakeSensorClient()
        self.isTerminal = isTerminal
        self.arguments = arguments
        self.now = now
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        self.interrupts = stream
        self.interrupt = continuation
    }

    var environment: CliEnvironment {
        return CliEnvironment(
            makeClient: { self.client },
            write: { self.output.write($0) },
            writeError: { self.errorOutput.write($0 + "\n") },
            isTerminal: self.isTerminal,
            now: { self.now },
            arguments: self.arguments,
            interrupts: { self.interrupts }
        )
    }
}

/// Installs a fresh `CliTestContext` and its `CliEnvironment` for the duration of a test.
struct CliEnvironmentTrait: TestTrait, TestScoping {
    /// 2026-10-22T10:00:00Z, the clock every test environment reports.
    static let fixedNow = Date(timeIntervalSince1970: 1_792_663_200)

    let isTerminal: Bool
    let arguments: [String]

    func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        let context = await CliTestContext(isTerminal: self.isTerminal, arguments: self.arguments, now: Self.fixedNow)

        try await CliTestContext.$current.withValue(context) {
            try await CliEnvironment.$current.withValue(context.environment) {
                try await function()
            }
        }
    }
}

extension Trait where Self == CliEnvironmentTrait {
    /// Runs the test against fakes; `arguments` is what `aranet-cli` was invoked with, for `--json` detection.
    static func cli(isTerminal: Bool = false, arguments: [String] = []) -> Self {
        return CliEnvironmentTrait(isTerminal: isTerminal, arguments: arguments)
    }
}

/// The context installed by the `.cli()` trait.
func currentContext() throws -> CliTestContext {
    return try #require(CliTestContext.current, "This test needs the .cli() trait")
}
