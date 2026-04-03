import AppKit
import Foundation
import Testing
@testable import WuZi

@MainActor
struct SettingsWindowControllerLayoutTests {
    @Test func firstLaunchStateDoesNotAutoOpenTheSettingsWindow() {
        let suiteName = #function
        let controller = makeSettingsWindowController(
            suiteName: suiteName,
            hasCompletedWelcome: false
        )
        defer { tearDown(controller: controller, suiteName: suiteName) }

        #expect(controller.window != nil)
        #expect(controller.window?.isVisible == false)
    }

    @Test func testOrganizationLayoutStaysStableAcrossPageSwitches() {
        let suiteName = #function
        let controller = makeSettingsWindowController(
            suiteName: suiteName,
            hasCompletedWelcome: true
        )
        defer { tearDown(controller: controller, suiteName: suiteName) }

        controller.showMainWindow(selecting: .testOrganization)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        let initialSnapshot = TestOrganizationLayoutSnapshot.capture(from: controller)

        controller.showMainWindow(selecting: .general)
        controller.showMainWindow(selecting: .testOrganization)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        let reopenedSnapshot = TestOrganizationLayoutSnapshot.capture(from: controller)

        #expect(initialSnapshot.scrollViews.count == 2)
        #expect(reopenedSnapshot.scrollViews.count == 2)
        guard initialSnapshot.scrollViews.count == 2, reopenedSnapshot.scrollViews.count == 2 else { return }

        #expect(initialSnapshot == TestOrganizationLayoutSnapshot.expected)
        #expect(reopenedSnapshot == initialSnapshot)
    }
}

@MainActor
private func makeSettingsWindowController(
    suiteName: String,
    hasCompletedWelcome: Bool
) -> SettingsWindowController {
    _ = NSApplication.shared
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let settingsStore = SettingsStore(userDefaults: defaults)
    settingsStore.hasCompletedWelcome = hasCompletedWelcome
    return SettingsWindowController(
        settingsStore: settingsStore,
        permissionCoordinator: PermissionCoordinator(),
        textOrganizationService: TextOrganizationService()
    )
}

@MainActor
private func tearDown(controller: SettingsWindowController, suiteName: String) {
    controller.close()
    controller.window?.orderOut(nil)
    UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
}

private struct TestOrganizationLayoutSnapshot: Equatable {
    let scrollViews: [ScrollViewLayoutSnapshot]

    static let expected = TestOrganizationLayoutSnapshot(scrollViews: [
        ScrollViewLayoutSnapshot(isEditable: true, widthConstants: [360], heightConstants: [300]),
        ScrollViewLayoutSnapshot(isEditable: false, widthConstants: [360], heightConstants: [300])
    ])

    @MainActor
    static func capture(from controller: SettingsWindowController) -> TestOrganizationLayoutSnapshot {
        guard let contentView = controller.window?.contentView else { return .init(scrollViews: []) }
        let scrollViews = descendantViews(in: contentView)
            .compactMap { $0 as? NSScrollView }
            .filter { $0.documentView is NSTextView }
            .sorted { lhs, rhs in
                let leftEditable = (lhs.documentView as? NSTextView)?.isEditable ?? false
                let rightEditable = (rhs.documentView as? NSTextView)?.isEditable ?? false
                if leftEditable != rightEditable {
                    return leftEditable && !rightEditable
                }
                return ObjectIdentifier(lhs).debugDescription < ObjectIdentifier(rhs).debugDescription
            }

        return TestOrganizationLayoutSnapshot(scrollViews: scrollViews.map(ScrollViewLayoutSnapshot.init))
    }
}

private struct ScrollViewLayoutSnapshot: Equatable {
    let isEditable: Bool
    let widthConstants: [CGFloat]
    let heightConstants: [CGFloat]

    @MainActor
    init(scrollView: NSScrollView) {
        let textView = scrollView.documentView as? NSTextView
        self.isEditable = textView?.isEditable ?? false
        self.widthConstants = equalConstantConstraints(on: scrollView, attribute: .width)
        self.heightConstants = equalConstantConstraints(on: scrollView, attribute: .height)
    }

    init(isEditable: Bool, widthConstants: [CGFloat], heightConstants: [CGFloat]) {
        self.isEditable = isEditable
        self.widthConstants = widthConstants
        self.heightConstants = heightConstants
    }
}

@MainActor
private func descendantViews(in view: NSView) -> [NSView] {
    view.subviews + view.subviews.flatMap(descendantViews)
}

@MainActor
private func equalConstantConstraints(on view: NSView, attribute: NSLayoutConstraint.Attribute) -> [CGFloat] {
    view.constraints
        .filter {
            ($0.firstItem as? NSView) === view &&
            $0.secondItem == nil &&
            $0.firstAttribute == attribute &&
            $0.relation == .equal
        }
        .map(\.constant)
        .sorted()
}
