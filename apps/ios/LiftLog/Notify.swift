import UserNotifications

/// Local notifications: the rest alarm (heard with the phone locked or in another app)
/// and the Wednesday 8 pm reminder when no workout is logged that week.
enum Notify {
    private static let center = UNUserNotificationCenter.current()
    private static let restID = "rest"
    private static let weeklyPrefix = "weekly-"
    /// Wednesdays scheduled ahead, so the reminder keeps coming if the app isn't opened.
    private static let weeksAhead = 6

    /// Asks once; later calls just answer with the current setting.
    private static func authorized(_ then: @escaping () -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { ok, _ in if ok { then() } }
    }

    /// `at` is the rest's end in ms since 1970; 0 cancels it.
    static func rest(at ms: Double, emom: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: [restID])
        let wait = ms / 1000 - Date().timeIntervalSince1970
        guard ms > 0, wait > 0.5 else { return }
        authorized {
            let c = UNMutableNotificationContent()
            c.title = emom ? "Next round" : "Rest over"
            c.body = "Time for your next set."
            c.sound = .default
            center.add(UNNotificationRequest(identifier: restID, content: c,
                                             trigger: UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false)))
        }
    }

    /// `last` is the date of the latest logged workout (YYYY-MM-DD, "" if none). Schedules the
    /// coming Wednesdays at 20:00, skipping this week's if a workout is already logged since Monday.
    static func weekly(last: String) {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .current
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        let lastDay = fmt.date(from: last)
        let now = Date()

        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(weeklyPrefix) })
            var fires: [Date] = []
            var from = now
            while fires.count < weeksAhead,
                  let wed = cal.nextDate(after: from, matching: DateComponents(hour: 20, minute: 0, weekday: 4), matchingPolicy: .nextTime) {
                from = wed
                let monday = cal.dateInterval(of: .weekOfYear, for: wed)?.start ?? wed
                if let d = lastDay, d >= monday { continue }
                fires.append(wed)
            }
            authorized {
                for wed in fires {
                    let c = UNMutableNotificationContent()
                    c.title = "No workout yet this week"
                    c.body = "It's Wednesday. Still time to get your sessions in."
                    c.sound = .default
                    let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: wed)
                    center.add(UNNotificationRequest(identifier: weeklyPrefix + fmt.string(from: wed), content: c,
                                                     trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
                }
            }
        }
    }
}

/// With the app open the page beeps itself, so the rest alarm stays quiet there; the reminder still shows.
final class NotifyDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotifyDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done(notification.request.identifier == "rest" ? [] : [.banner, .sound])
    }
}
