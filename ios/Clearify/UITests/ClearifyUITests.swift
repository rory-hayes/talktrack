import XCTest

final class ClearifyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingCompletesOnceAndReturnsToDashboard() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_RESET_STATE"]
        app.launch()

        tap(button: app.buttons["Continue"])
        tap(button: app.buttons["Continue"])
        tap(button: app.buttons["Set up my plan"])

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "Expected email field on account screen")

        let testEmail = "audit.e2e+\(Int(Date().timeIntervalSince1970))@example.com"
        enterText(testEmail, into: emailField)
        enterText("Audit123", into: app.secureTextFields["Password"])
        tap(button: app.buttons["Create account with email"])

        let notNowButton = app.buttons["Not Now"]
        if notNowButton.waitForExistence(timeout: 5) {
            notNowButton.tap()
        }

        let accountContinueButton = app.buttons["Continue"]
        if !app.textFields["First name"].waitForExistence(timeout: 3), accountContinueButton.waitForExistence(timeout: 3) {
            accountContinueButton.tap()
        }

        let firstNameField = app.textFields["First name"]
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 20), "Expected profile step after sign-in")
        let firstNameValue = firstNameField.value as? String ?? ""
        if firstNameValue == "First name" || firstNameValue.isEmpty {
            if firstNameField.isHittable {
                firstNameField.tap()
            } else {
                firstNameField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            firstNameField.typeText("Audit")
            dismissKeyboardIfNeeded(in: app)
        }

        dismissKeyboardIfNeeded(in: app)
        tap(button: app.buttons["Continue"])

        let dashboardButton = app.buttons["Go to dashboard"]
        XCTAssertTrue(dashboardButton.waitForExistence(timeout: 10), "Expected focus step")
        tap(button: dashboardButton)

        XCTAssertTrue(app.staticTexts["Start here"].waitForExistence(timeout: 15), "Expected dashboard to load")

        app.terminate()
        app.launchArguments.removeAll { $0 == "UITEST_RESET_STATE" }
        app.launch()

        XCTAssertTrue(app.staticTexts["Start here"].waitForExistence(timeout: 15), "Expected returning user to land on dashboard")
        XCTAssertFalse(app.staticTexts["Create your account"].exists, "Returning user should not see onboarding again")
    }

    private func tap(button: XCUIElement, timeout: TimeInterval = 10) {
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Missing button: \(button)")
        if !button.isHittable {
            let app = XCUIApplication()
            for _ in 0..<4 where !button.isHittable {
                app.swipeUp()
            }
        }
        if button.isHittable {
            button.tap()
        } else {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func enterText(_ text: String, into field: XCUIElement, timeout: TimeInterval = 10) {
        XCTAssertTrue(field.waitForExistence(timeout: timeout), "Missing input field")
        field.tap()
        field.typeText(text)
    }

    private func dismissKeyboardIfNeeded(in app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }

        let returnButtonLabels = ["Return", "Done", "Continue", "Join", "Go"]
        for label in returnButtonLabels {
            let button = app.keyboards.buttons[label]
            if button.exists {
                button.tap()
                return
            }
        }

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
    }
}
