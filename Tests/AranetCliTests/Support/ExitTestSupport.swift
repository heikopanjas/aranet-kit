import Foundation

/// Exit tests spawn the test runner again as a child process. Under Thread Sanitizer that child
/// produces neither output nor a matching exit code, so the suites that depend on it are skipped there.
enum ExitTestSupport {
    static let isAvailable: Bool = {
        guard let program = dlopen(nil, RTLD_NOW) else { return true }
        defer { dlclose(program) }
        return dlsym(program, "__tsan_init") == nil
    }()
}
