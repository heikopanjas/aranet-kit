import ArgumentParser
import Foundation
import Testing

@testable import AranetCli

@Suite(.tags(.cli))
struct GlobalOptionsTests {
    @Test("Defaults are quiet, non-JSON, with a 15 second timeout", .cli())
    func defaults() throws -> Void {
        let options = try GlobalOptions.parse([])

        #expect(options.verbose == false)
        #expect(options.jsonFlag == false)
        #expect(options.json == false)
        #expect(options.timeout == 15)
        #expect(options.clientVerbose == false)
        #expect(options.showSpinner == false)
        #expect(options.showStatusText == true)
    }

    @Test("The timeout accepts both spellings", arguments: [["--timeout", "3"], ["-t", "3"]])
    func timeoutSpellings(arguments: [String]) throws -> Void {
        let options = try GlobalOptions.parse(arguments)

        #expect(options.timeout == 3)
    }

    @Test("A hidden --json flag after the subcommand enables JSON mode", .cli())
    func jsonFlagAfterSubcommand() throws -> Void {
        let options = try GlobalOptions.parse(["--json"])

        #expect(options.json == true)
        #expect(options.showStatusText == false)
        #expect(options.showSpinner == false)
    }

    @Test("A --json flag before the subcommand is detected from the invocation", .cli(arguments: ["--json", "scan"]))
    func jsonFlagBeforeSubcommand() throws -> Void {
        let options = try GlobalOptions.parse([])

        #expect(options.jsonFlag == false)
        #expect(options.json == true)
        #expect(AranetCli.jsonRequested == true)
    }

    @Test("Verbose output goes to the client and disables the spinner", .cli(isTerminal: true))
    func verboseDisablesSpinner() throws -> Void {
        let options = try GlobalOptions.parse(["--verbose"])

        #expect(options.clientVerbose == true)
        #expect(options.showSpinner == false)
        #expect(options.showStatusText == true)
    }

    @Test("Verbose is suppressed for the client in JSON mode", .cli(isTerminal: true))
    func verboseSuppressedInJsonMode() throws -> Void {
        let options = try GlobalOptions.parse(["-v", "--json"])

        #expect(options.verbose == true)
        #expect(options.clientVerbose == false)
    }

    @Test("The spinner is shown only on a quiet terminal", .cli(isTerminal: true))
    func spinnerOnTerminal() throws -> Void {
        let options = try GlobalOptions.parse([])

        #expect(options.showSpinner == true)
    }
}
