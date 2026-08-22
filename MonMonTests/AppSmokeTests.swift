import Testing

@testable import MonMon

@Suite("App bootstrap")
struct AppSmokeTests {
    @Test("Greeting copy is stable")
    func greetingCopyIsStable() {
        #expect(AppCopy.greeting == "Hello, MonMon")
    }
}
