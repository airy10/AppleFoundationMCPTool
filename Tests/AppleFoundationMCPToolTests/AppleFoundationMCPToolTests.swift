import XCTest
@testable import AppleFoundationMCPTool

final class AppleFoundationMCPToolTests: XCTestCase {
    func testAppleFoundationMCPToolCreation() {
        // This is a simple test to verify that the tool can be created
        // Note: We can't actually test the AI functionality without running on a device with the Foundation Models framework
        let tool = AppleFoundationMCPTool()
        XCTAssertNotNil(tool)
    }
    
    func testSessionManagerCreation() {
        // This is a simple test to verify that the session manager can be created
        // Note: We can't actually test the AI functionality without running on a device with the Foundation Models framework
        let sessionManager = SessionManager()
        XCTAssertNotNil(sessionManager)
    }
}