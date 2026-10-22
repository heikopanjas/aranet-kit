import Foundation
import Testing

@testable import AranetCli

/// Exit tests run the entry point in a child process, so the `Never`-returning exit paths are covered too.
@Suite(.tags(.cli))
struct AranetCliMainTests {
    private static let observed: [any PartialKeyPath<ExitTest.Result> & Sendable] = [\.standardOutputContent, \.standardErrorContent]

    private static func stdout(_ result: ExitTest.Result?) -> String {
        return String(decoding: result?.standardOutputContent ?? [], as: UTF8.self)
    }

    /// The child's standard error, shown when an expectation fails so a crash in the child is diagnosable.
    private static func stderr(_ result: ExitTest.Result?) -> Comment {
        return Comment(rawValue: "stderr: " + String(decoding: result?.standardErrorContent ?? [], as: UTF8.self))
    }

    @Test("--version prints the version and exits successfully")
    func versionFlag() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: Self.observed) {
            await AranetCliMain.run(arguments: ["--version"])
        }

        #expect(Self.stdout(result).contains("4.0.0") == true, Self.stderr(result))
    }

    @Test("No arguments prints help and exits successfully")
    func helpWithoutArguments() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: Self.observed) {
            await AranetCliMain.run(arguments: [])
        }

        #expect(Self.stdout(result).contains("USAGE") == true, Self.stderr(result))
    }

    @Test("--json alone still prints help")
    func helpWithJson() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: Self.observed) {
            await AranetCliMain.run(arguments: ["--json"])
        }

        #expect(Self.stdout(result).contains("USAGE") == true, Self.stderr(result))
    }

    @Test("A parse error exits with the usage code")
    func parseError() async -> Void {
        let result = await #expect(processExitsWith: .exitCode(64), observing: Self.observed) {
            await AranetCliMain.run(arguments: ["scan", "--bogus"])
        }

        #expect(Self.stdout(result).isEmpty == true, Self.stderr(result))
    }

    @Test("A parse error in JSON mode is reported as a JSON line on standard output")
    func parseErrorJson() async -> Void {
        let result = await #expect(processExitsWith: .exitCode(64), observing: Self.observed) {
            await AranetCliMain.run(arguments: ["scan", "--json", "--bogus"])
        }

        let output = Self.stdout(result)
        #expect(output.hasPrefix("{\"error\":") == true, Self.stderr(result))
        #expect(output.contains("bogus") == true)
    }

    @Test("A missing argument exits with the usage code")
    func missingArgument() async -> Void {
        let result = await #expect(processExitsWith: .exitCode(64), observing: Self.observed) {
            await AranetCliMain.run(arguments: ["monitor"])
        }

        #expect(Self.stdout(result).isEmpty == true, Self.stderr(result))
    }

    @Test("The entry point runs the configured arguments")
    func mainUsesEnvironmentArguments() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: Self.observed) {
            await CliEnvironment.$current.withValue(CliEnvironment.live.with(arguments: ["--version"])) {
                await AranetCliMain.main()
            }
        }

        #expect(Self.stdout(result).contains("4.0.0") == true, Self.stderr(result))
    }
}
