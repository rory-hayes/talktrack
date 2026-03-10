import XCTest

final class ClearifyUITests: XCTestCase {
    private let onboardingDebugLabelID = "debug.onboarding.state"
    private let onboardingDebugEventsID = "debug.onboarding.events"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingCompletesOnceAndReturnsToDashboard() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_RESET_STATE"]
        app.launch()

        completeOnboarding(in: app)

        XCTAssertTrue(app.staticTexts["Start here"].waitForExistence(timeout: 15), "Expected dashboard to load")

        app.terminate()
        app.launchArguments.removeAll { $0 == "UITEST_RESET_STATE" }
        app.launch()

        XCTAssertTrue(app.staticTexts["Start here"].waitForExistence(timeout: 15), "Expected returning user to land on dashboard")
        XCTAssertFalse(app.staticTexts["Create your account"].exists, "Returning user should not see onboarding again")
    }

    func testAuthenticatedBootstrapLaunchesToDashboard() throws {
        let app = launchAuthenticatedDashboard()

        XCTAssertTrue(app.staticTexts["Start here"].exists, "Expected authenticated dashboard to load")
        XCTAssertFalse(app.staticTexts["Create your account"].exists, "Authenticated bootstrap should bypass onboarding")
    }

    func testFullSessionStartsFromDashboard() throws {
        let app = launchAuthenticatedDashboard()
        tap(button: app.buttons["home.startFullSession"])

        XCTAssertTrue(app.staticTexts["Full Session"].waitForExistence(timeout: 15), "Expected full session screen")
        XCTAssertTrue(app.staticTexts["Tap to start your answer"].waitForExistence(timeout: 15), "Expected ready-to-record state")
    }

    func testQuickDrillStartsFromDashboard() throws {
        let app = launchAuthenticatedDashboard()

        tap(button: app.buttons["home.startQuickDrill"])

        XCTAssertTrue(app.staticTexts["Quick Drill"].waitForExistence(timeout: 15), "Expected quick drill screen")
        XCTAssertTrue(app.staticTexts["Tap to start your answer"].waitForExistence(timeout: 15), "Expected ready-to-record state")
    }

    private func launchAuthenticatedDashboard(resetState: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        if resetState {
            app.launchArguments += ["UITEST_RESET_STATE"]
        }
        app.launchArguments += ["UITEST_BOOTSTRAP_AUTHENTICATED"]
        app.launch()

        let dashboardHeader = app.staticTexts["Start here"]
        if !dashboardHeader.waitForExistence(timeout: 20) {
            attachDebugState(of: app, named: "authenticated-dashboard-stuck")
        }
        XCTAssertTrue(dashboardHeader.waitForExistence(timeout: 20), "Expected authenticated dashboard to load")
        return app
    }

    private func completeOnboarding(in app: XCUIApplication) {
        tap(button: app.buttons["onboarding.footer.introPractice"])
        tap(button: app.buttons["onboarding.footer.introCoach"])
        tap(button: app.buttons["onboarding.footer.introProgress"])

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "Expected email field on account screen")

        let testEmail = "audit.e2e+\(Int(Date().timeIntervalSince1970))@example.com"
        enterText(testEmail, into: emailField)
        enterText("Audit123", into: app.secureTextFields["Password"])
        tap(button: app.buttons["Create account with email"])

        dismissPasswordPromptIfPresent(app: app)

        let accountContinueButton = app.buttons["onboarding.footer.account"]
        if !app.textFields["First name"].waitForExistence(timeout: 3), accountContinueButton.waitForExistence(timeout: 3) {
            accountContinueButton.tap()
        }

        let firstNameField = app.textFields["First name"]
        if !firstNameField.waitForExistence(timeout: 20) {
            attachDebugState(of: app, named: "onboarding-stuck-after-account")
        }
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
        tap(button: app.buttons["onboarding.footer.profile"], allowsScrollRecovery: false, hittableTimeout: 4)

        let dashboardButton = app.buttons["onboarding.footer.focus"]
        if !dashboardButton.waitForExistence(timeout: 10) {
            attachOnboardingDebugState(of: app, named: "onboarding-debug-after-profile")
            attachDebugState(of: app, named: "onboarding-stuck-after-profile")
        }
        XCTAssertTrue(dashboardButton.waitForExistence(timeout: 10), "Expected focus step")
        attachOnboardingDebugState(of: app, named: "onboarding-debug-before-focus-tap")
        tap(button: dashboardButton, allowsScrollRecovery: false, hittableTimeout: 4)
    }

    private func tap(
        button: XCUIElement,
        timeout: TimeInterval = 10,
        allowsScrollRecovery: Bool = true,
        hittableTimeout: TimeInterval = 2
    ) {
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Missing button: \(button)")
        waitForHittable(button, timeout: hittableTimeout)
        if allowsScrollRecovery && !button.isHittable {
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

    private func dismissPasswordPromptIfPresent(app: XCUIApplication, timeout: TimeInterval = 8) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let candidates = [
                app.buttons["Not Now"],
                springboard.buttons["Not Now"],
                springboard.alerts.buttons["Not Now"],
                springboard.sheets.buttons["Not Now"]
            ]

            if let button = candidates.first(where: \.exists) {
                if button.isHittable {
                    button.tap()
                } else {
                    button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 2) {
        guard !element.isHittable else { return }

        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
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

    private func attachDebugState(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachOnboardingDebugState(of app: XCUIApplication, named name: String) {
        let debugLabel = app.staticTexts[onboardingDebugLabelID]
        let summary = debugLabel.exists ? debugLabel.label : "missing-debug-label"
        let debugEventsLabel = app.staticTexts[onboardingDebugEventsID]
        let events = debugEventsLabel.exists ? debugEventsLabel.label : "missing-debug-events"
        let profileFooter = app.buttons["onboarding.footer.profile"]
        let focusFooter = app.buttons["onboarding.footer.focus"]
        let attachment = XCTAttachment(
            string: """
            summary=\(summary)
            events=
            \(events)
            profileFooter.exists=\(profileFooter.exists)
            profileFooter.hittable=\(profileFooter.isHittable)
            focusFooter.exists=\(focusFooter.exists)
            focusFooter.hittable=\(focusFooter.isHittable)
            """
        )
        print(
            """
            ONBOARDING_TEST_DEBUG name=\(name)
            summary=\(summary)
            events=
            \(events)
            profileFooter.exists=\(profileFooter.exists)
            profileFooter.hittable=\(profileFooter.isHittable)
            focusFooter.exists=\(focusFooter.exists)
            focusFooter.hittable=\(focusFooter.isHittable)
            """
        )
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
