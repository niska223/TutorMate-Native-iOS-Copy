import XCTest
@testable import TutorMate

final class TutorMateTests: XCTestCase {
    @MainActor
    func testSignInRoutesToTutorHome() {
        let app = AppController()
        app.signIn(name: "Test Tutor", email: "tutor@example.com", role: .tutor)
        XCTAssertEqual(app.route, .tutor)
        XCTAssertEqual(app.displayName, "Test Tutor")
    }

    @MainActor
    func testPaymentTotalOnlyIncludesPaidRecords() {
        let app = AppController()
        XCTAssertEqual(app.collectedIncome, app.payments.filter(\.isPaid).reduce(0) { $0 + $1.amount })
    }
}
