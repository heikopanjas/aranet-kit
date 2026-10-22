import ArgumentParser
import Foundation
import Testing

@testable import AranetCli

@Suite(.tags(.cli))
struct ExitPlanTests {
    private struct SomethingBroke: Error {}

    @Test("Without --json every error passes through to the argument parser")
    func passThroughWithoutJson() -> Void {
        #expect(ExitPlan.make(for: ValidationError("bad"), jsonRequested: false) == .passThrough)
        #expect(ExitPlan.make(for: ExitCode.failure, jsonRequested: false) == .passThrough)
    }

    @Test("Help and version requests keep their regular output in JSON mode")
    func cleanExitsPassThrough() -> Void {
        let help = CleanExit.helpRequest(AranetCli())

        #expect(ExitPlan.make(for: help, jsonRequested: true) == .passThrough)
        #expect(ExitPlan.make(for: ExitCode.success, jsonRequested: true) == .passThrough)
    }

    @Test("Validation errors become a JSON error with the usage exit code")
    func validationErrorsBecomeJson() -> Void {
        let plan = ExitPlan.make(for: ValidationError("Missing expected argument"), jsonRequested: true)

        #expect(plan == .json(message: "Missing expected argument", code: .validationFailure))
    }

    @Test("Exit codes without a message exit silently")
    func exitCodesWithoutMessage() -> Void {
        #expect(ExitPlan.make(for: ExitCode.failure, jsonRequested: true) == .json(message: nil, code: .failure))
        #expect(ExitPlan.make(for: ExitCode(3), jsonRequested: true) == .json(message: nil, code: ExitCode(3)))
    }

    @Test("Other errors become a JSON error with the failure exit code")
    func otherErrorsBecomeJson() -> Void {
        let plan = ExitPlan.make(for: SomethingBroke(), jsonRequested: true)

        guard case .json(let message, let code) = plan else {
            Issue.record("Expected a JSON plan, got \(plan)")
            return
        }
        #expect(message?.isEmpty == false)
        #expect(code == .failure)
    }
}
