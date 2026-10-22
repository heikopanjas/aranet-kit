import Foundation
import Testing

@testable import AranetCli

/// Exit tests run the entry point in a child process, so the `Never`-returning exit paths are covered too.
@Suite(.tags(.cli), .enabled(if: ExitTestSupport.isAvailable, "Exit tests cannot run under Thread Sanitizer"))
struct AranetCliMainTests {
    private static let observed: [any PartialKeyPath<ExitTest.Result> & Sendable] = [\.standardOutputContent, \.standardErrorContent]

    private static func stdout(_ result: ExitTest.Result?) -> String {
        return String(decoding: result?.standardOutputContent ?? [], as: UTF8.self)
    }

    private static func stderr(_ result: ExitTest.Result?) -> String {
        return String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
    }

    /// The child's standard error as a comment, shown when an expectation fails so a crash in the child is diagnosable.
    private static func diagnostics(_ result: ExitTest.Result?) -> Comment {
        return Comment(rawValue: "stderr: " + Self.diagnostics(result))
    }

    @Test("--version prints the version and exits successfully")
    func versionFlag() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: Self.observed) {
            await AranetCliMain.run(arguments: ["--version"])
        }

        #expect(Self.stdout(result).contains("4.0.0") == true, Self.diagnostics(result))
    }

    @Test("No arguments prints help and exits successfully")
    func helpWithoutArguments() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: Self.observed) {
            await AranetCliMain.run(arguments: [])
        }

        #expect(Self.stdout(result).contains("USAGE") == true, Self.diagnostics(result))
    }

    @Test("--json alone still prints help")
    func helpWithJson() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: Self.observed) {
            await AranetCliMain.run(arguments: ["--json"])
        }

        #expect(Self.stdout(result).contains("USAGE") == true, Self.diagnostics(result))
    }

    @Test("A parse error exits with the usage code")
    func parseError() async -> Void {
        let result = await #expect(processExitsWith: .exitCode(64), observing: Self.observed) {
            await AranetCliMain.run(arguments: ["scan", "--bogus"])
        }

        #expect(Self.stderr(result).contains("Unknown option '--bogus'") == true, Self.diagnostics(result))
    }

    @Test("A parse error in JSON mode is reported as a JSON line on standard output")
    func parseErrorJson() async -> Void {
        let result = await #expect(processExitsWith: .exitCode(64), observing: Self.observed) {
            await AranetCliMain.run(arguments: ["scan", "--json", "--bogus"])
        }

        let output = Self.stdout(result)
        #expect(output.hasPrefix("{\"error\":") == true, Self.diagnostics(result))
        #expect(output.contains("bogus") == true)
    }

    @Test("A missing argument exits with the usage code")
    func missingArgument() async -> Void {
        let result = await #expect(processExitsWith: .exitCode(64), observing: Self.observed) {
            await AranetCliMain.run(arguments: ["monitor"])
        }

        #expect(Self.stderr(result).contains("Missing expected argument") == true, Self.diagnostics(result))
    }

    @Test("The entry point runs the configured arguments")
    func mainUsesEnvironmentArguments() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: Self.observed) {
            await CliEnvironment.$current.withValue(CliEnvironment.live.with(arguments: ["--version"])) {
                await AranetCliMain.main()
            }
        }

        #expect(Self.stdout(result).contains("4.0.0") == true, Self.diagnostics(result))
    }
}
