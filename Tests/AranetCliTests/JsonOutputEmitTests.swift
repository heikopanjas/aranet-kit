import AranetKit
import Foundation
import Testing

@testable import AranetCli

@Suite(.tags(.cli, .formatting))
struct JsonOutputEmitTests {
    private struct Unencodable: Encodable {
        struct Failure: Error {}

        func encode(to encoder: any Encoder) throws {
            throw Failure()
        }
    }

    @Test("emit writes pretty JSON followed by a newline", .cli())
    func emitPretty() throws -> Void {
        let context = try currentContext()

        try JsonOutput.emit(["b": 1, "a": 2])

        let text = context.output.text
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Int]
        #expect(text.hasPrefix("{\n") == true, "Pretty output spans several lines")
        #expect(text.hasSuffix("\n}\n") == true, "Pretty output ends with a newline")
        #expect(object == ["a": 2, "b": 1])
    }

    @Test("emit can write a single line", .cli())
    func emitSingleLine() throws -> Void {
        let context = try currentContext()

        try JsonOutput.emit(["b": 1, "a": 2], pretty: false)

        #expect(context.output.text == "{\"a\":2,\"b\":1}\n")
    }

    @Test("Values that cannot be encoded are reported on standard error and throw", .cli())
    func encodingFailure() throws -> Void {
        let context = try currentContext()

        #expect(throws: JsonOutput.EncodingFailure()) {
            try JsonOutput.emit(Unencodable())
        }
        #expect(context.output.text.isEmpty == true)
        #expect(context.errorOutput.text.hasPrefix("error: could not encode JSON output:") == true)
    }

    @Test("emitError writes one error line, with or without a device", .cli())
    func emitErrorLines() throws -> Void {
        let context = try currentContext()

        JsonOutput.emitError("Device not found", device: "Aranet4 1A2B3")
        JsonOutput.emitError("Bluetooth is unavailable or not ready")

        let expected = [
            "{\"device\":\"Aranet4 1A2B3\",\"error\":\"Device not found\"}",
            "{\"error\":\"Bluetooth is unavailable or not ready\"}"
        ]
        #expect(context.output.lines == expected)
    }

    @Test("emitError accepts any error and uses its localized description", .cli())
    func emitErrorFromError() throws -> Void {
        let context = try currentContext()

        JsonOutput.emitError(AranetError.timeout)

        #expect(context.output.lines == ["{\"error\":\"Operation timed out\"}"])
    }
}
