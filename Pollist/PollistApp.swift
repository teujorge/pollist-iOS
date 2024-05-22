//
//  PollistApp.swift
//  Pollist
//
//  Created by Matheus Jorge on 5/22/24.
//

import SwiftUI
import UserNotifications

@main
struct PollistApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleUniversalLink(url)
                }
                .onAppear {
                    UIApplication.shared.registerForRemoteNotifications()
                    UNUserNotificationCenter.current().delegate = appDelegate
                }
        }
    }
    
    private func handleUniversalLink(_ url: URL) {
        LinkManager.shared.universalURL = url
        NotificationCenter.default.post(name: NSNotification.Name("UniversalLinkReceived"), object: nil)
    }
}

class LinkManager {
    static let shared = LinkManager()
    var universalURL: URL?
    var webViewURL = URL(string: "https://pollist.org")!
    var webViewSheetURL = URL(string: "https://pollist.org")!
}


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        initPushNotifications()
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { String(format: "%02.2hhx", $0) }
        let token = tokenParts.joined()
        UserDefaults.standard.set(token, forKey: "deviceToken")
        NotificationCenter.default.post(name: NSNotification.Name("DeviceTokenUpdated"), object: nil)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: NSNotification.Name("DeviceTokenUpdateFailed"), object: ["error": error.localizedDescription])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
        resetNotificationBadge(center: center)
    }
    
    private func initPushNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                NSLog("Error requesting notifications authorization: \(error)")
            }
            guard granted else {
                NotificationCenter.default.post(name: NSNotification.Name("UserDeniedNotifications"), object: nil)
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
                self.resetNotificationBadge(center: center)
            }
        }
    }
    
    private func resetNotificationBadge(center: UNUserNotificationCenter) {
        center.setBadgeCount(0) { error in
            if let error = error {
                NSLog("Error setting badge count: \(error)")
            } else {
                center.removeAllDeliveredNotifications()
            }
        }
    }
}
