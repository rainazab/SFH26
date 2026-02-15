//
//  AppNotificationService.swift
//  Bottle
//
//  Local notifications for key realtime events.
//

import Foundation
import UserNotifications

final class AppNotificationService {
    static let shared = AppNotificationService()

    private var didRequestPermission = false

    private init() {}

    func requestPermissionIfNeeded() {
        guard !didRequestPermission else { return }
        didRequestPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notifyNewPostNearby(count: Int) {
        schedule(
            idPrefix: "new-post",
            title: "New post nearby",
            body: count == 1 ? "A new post is available near you." : "\(count) new posts are available near you."
        )
    }

    func notifyPostPickedUp() {
        schedule(
            idPrefix: "post-picked-up",
            title: "Post picked up",
            body: "A collector has claimed your post."
        )
    }

    func notifyPostCompleted() {
        schedule(
            idPrefix: "post-completed",
            title: "Post completed",
            body: "Your claimed post has been completed."
        )
    }

    private func schedule(idPrefix: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(idPrefix)-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
