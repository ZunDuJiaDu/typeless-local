import Testing
@testable import WuZi

struct MainWindowNavigationTests {
    @Test func registersExpectedSidebarPages() {
        #expect(MainWindowNavigationModel().pages == [
            .welcome,
            .general,
            .speechRecognition,
            .ollamaOrganization,
            .testOrganization,
            .injectionAndPaste,
            .advanced,
            .about
        ])
    }

    @Test func routesFirstLaunchToWelcome() {
        let navigation = MainWindowNavigationModel()
        #expect(navigation.initialPage(hasCompletedWelcome: false) == .welcome)
        #expect(navigation.initialPage(hasCompletedWelcome: true) == .general)
    }
}
