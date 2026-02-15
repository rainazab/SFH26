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
    static let openCollectionPointNotification = Notification.Name("bottlr.openCollectionPoint")
    static let postIDUserInfoKey = "postId"
    private enum Keys {
        static let newPostAlertsEnabled = "bottlr.notifications.newPosts.enabled"
        static let pickupAlertsEnabled = "bottlr.notifications.pickups.enabled"
    }

    private var didRequestPermission = false

    private init() {}

    var newPostAlertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.newPostAlertsEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.newPostAlertsEnabled) }
    }

    var pickupAlertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.pickupAlertsEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.pickupAlertsEnabled) }
    }

    func requestPermissionIfNeeded() {
        guard !didRequestPermission else { return }
        didRequestPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notifyNewPostNearby(count: Int, postId: String?) {
        guard newPostAlertsEnabled else { return }
        schedule(
            idPrefix: "new-post",
            title: "New post nearby",
            body: count == 1 ? "A new post is available near you." : "\(count) new posts are available near you.",
            postId: postId
        )
    }

    func notifyPostPickedUp(postId: String?) {
        guard pickupAlertsEnabled else { return }
        schedule(
            idPrefix: "post-picked-up",
            title: "Post picked up",
            body: "A collector has claimed your post.",
            postId: postId
        )
    }

    func notifyPostCompleted(postId: String?) {
        guard pickupAlertsEnabled else { return }
        schedule(
            idPrefix: "post-completed",
            title: "Post completed",
            body: "Your claimed post has been completed.",
            postId: postId
        )
    }

    func routeToCollectionPoint(postId: String) {
        NotificationCenter.default.post(
            name: Self.openCollectionPointNotification,
            object: nil,
            userInfo: [Self.postIDUserInfoKey: postId]
        )
    }

    private func schedule(idPrefix: String, title: String, body: String, postId: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let postId {
            content.userInfo = [Self.postIDUserInfoKey: postId]
        }

        let request = UNNotificationRequest(
            identifier: "\(idPrefix)-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
