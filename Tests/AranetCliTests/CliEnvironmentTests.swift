import Foundation
import Testing

@testable import AranetCli

@Suite(.tags(.cli))
struct CliEnvironmentTests {
    @Test("printLine appends a newline to the written text", .cli())
    func printLineAppendsNewline() throws -> Void {
        let context = try currentContext()

        CliEnvironment.current.printLine("hello")

        #expect(context.output.text == "hello\n")
    }

    @Test("with(arguments:) replaces only the arguments", .cli(isTerminal: true, arguments: ["scan"]))
    func withArguments() -> Void {
        let environment = CliEnvironment.current.with(arguments: ["read", "--json"])

        #expect(environment.arguments == ["read", "--json"])
        #expect(environment.isTerminal == true)
    }

    @Test("The live environment reflects the process")
    func liveEnvironment() -> Void {
        let live = CliEnvironment.live
        let before = Date()

        #expect(live.arguments == Array(CommandLine.arguments.dropFirst()))
        #expect(live.isTerminal == (isatty(STDOUT_FILENO) == 1))
        #expect(live.now() >= before)
        live.write("")
        live.writeError("")
    }

    @Test("The live interrupt stream delivers SIGINT until its consumer is cancelled", .timeLimit(.minutes(1)))
    @MainActor
    func liveInterrupts() async -> Void {
        let stream = CliEnvironment.live.interrupts()
        let received = Counter()
        let consumer = Task { @MainActor in
            for await _ in stream {
                received.count += 1
            }
        }

        kill(getpid(), SIGINT)
        await settle("the interrupt to arrive") { received.count == 1 }

        consumer.cancel()
        await consumer.value

        #expect(received.count == 1)
    }
}
