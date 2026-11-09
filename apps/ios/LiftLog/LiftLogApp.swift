import SwiftUI
import UserNotifications

@main
struct LiftLogApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotifyDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            WebView()
                .ignoresSafeArea()
                .background(Color(uiColor: .appBackground).ignoresSafeArea())
                .onAppear {
                    // Putting the phone down jolts it enough to trigger iOS's
                    // "Undo Typing" alert. Nobody shakes to undo mid-workout.
                    UIApplication.shared.applicationSupportsShakeToEdit = false
                }
        }
    }
}

extension UIColor {
    /// `--bg` from liftlog.html, so launch and overscroll match the page.
    static let appBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x08 / 255, green: 0x12 / 255, blue: 0x1E / 255, alpha: 1)
            : UIColor(red: 0xF1 / 255, green: 0xF4 / 255, blue: 0xF8 / 255, alpha: 1)
    }
}
