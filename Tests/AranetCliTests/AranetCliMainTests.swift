import Foundation
import Testing

@testable import AranetCli

/// Exit tests run the entry point in a child process, so the `Never`-returning exit paths are covered too.
@Suite(.tags(.cli))
struct AranetCliMainTests {
    @Test("--version prints the version and exits successfully")
    func versionFlag() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: [\.standardOutputContent]) {
            await AranetCliMain.run(arguments: ["--version"])
        }

        let output = String(decoding: result?.standardOutputContent ?? [], as: UTF8.self)
        #expect(output.contains("4.0.0") == true)
    }

    @Test("No arguments prints help and exits successfully")
    func helpWithoutArguments() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: [\.standardOutputContent]) {
            await AranetCliMain.run(arguments: [])
        }

        let output = String(decoding: result?.standardOutputContent ?? [], as: UTF8.self)
        #expect(output.contains("USAGE") == true)
    }

    @Test("--json alone still prints help")
    func helpWithJson() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: [\.standardOutputContent]) {
            await AranetCliMain.run(arguments: ["--json"])
        }

        let output = String(decoding: result?.standardOutputContent ?? [], as: UTF8.self)
        #expect(output.contains("USAGE") == true)
    }

    @Test("A parse error exits with the usage code")
    func parseError() async -> Void {
        await #expect(processExitsWith: .exitCode(64)) {
            await AranetCliMain.run(arguments: ["scan", "--bogus"])
        }
    }

    @Test("A parse error in JSON mode is reported as a JSON line on standard output")
    func parseErrorJson() async -> Void {
        let result = await #expect(processExitsWith: .exitCode(64), observing: [\.standardOutputContent]) {
            await AranetCliMain.run(arguments: ["scan", "--json", "--bogus"])
        }

        let output = String(decoding: result?.standardOutputContent ?? [], as: UTF8.self)
        #expect(output.hasPrefix("{\"error\":") == true)
        #expect(output.contains("bogus") == true)
    }

    @Test("A missing argument exits with the usage code")
    func missingArgument() async -> Void {
        await #expect(processExitsWith: .exitCode(64)) {
            await AranetCliMain.run(arguments: ["monitor"])
        }
    }

    @Test("The entry point runs the configured arguments")
    func mainUsesEnvironmentArguments() async -> Void {
        let result = await #expect(processExitsWith: .success, observing: [\.standardOutputContent]) {
            await CliEnvironment.$current.withValue(CliEnvironment.live.with(arguments: ["--version"])) {
                await AranetCliMain.main()
            }
        }

        let output = String(decoding: result?.standardOutputContent ?? [], as: UTF8.self)
        #expect(output.contains("4.0.0") == true)
    }
}
