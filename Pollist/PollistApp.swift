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
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    WebViewManager.shared.handleDeepLink(url)
                }
                .onAppear {
                    UNUserNotificationCenter.current().delegate = appDelegate
                }
        }
    }

}

class WebViewManager: ObservableObject {
    static let shared = WebViewManager()
    
    // Links
    var deepLinkURL: URL?
    @Published var webViewURL = URL(string: "https://\(webDomain)")!
    var webViewSheetURL = URL(string: "https://\(webDomain)")!
    
    // Properties
    var userID: String? {
        didSet {
            if userID != UserDefaults.standard.string(forKey: .userID) {
                UserDefaults.standard.set(userID, forKey: .userID)
                print("User ID updated, setting UserDefaults: \(userID ?? "nil")")
            }
        }
    }
    
    init() {
        userID = UserDefaults.standard.string(forKey: .userID)
        print("User ID from UserDefaults: \(userID ?? "nil")")
    }
    
    // Handle all deep link URLs through this method
    func handleDeepLink(_ url: URL) {
        self.deepLinkURL = url
        NotificationCenter.default.post(name: NSNotification.Name("DeepLinkReceived"), object: nil)
        print("Deep link URL received: \(url)")
    }
}


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        initPushNotifications()
        
        // Handle launch options if app is opened from a notification
        NSLog("Launch options \(String(describing: launchOptions))")
        if let notificationURL = launchOptions?[.remoteNotification] as? [String: AnyObject],
           let urlString = notificationURL["url"] as? String,
           let url = URL(string: "https://\(webDomain)\(urlString)") {
            WebViewManager.shared.handleDeepLink(url)
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { String(format: "%02.2hhx", $0) }
        let token = tokenParts.joined()
        print("set device token \(token)")
        UserDefaults.standard.set(token, forKey: .deviceToken)
        NotificationCenter.default.post(name: NSNotification.Name("DeviceTokenUpdated"), object: nil)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: NSNotification.Name("DeviceTokenUpdateFailed"), object: ["error": error.localizedDescription])
    }
    
    // Set foreground notification types
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
        resetNotificationBadge(center: center)
    }
    
    // Handling notification URLs
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("handle didReceive notification \(String(describing: response.notification.request.content.userInfo["url"]))")
        if let url = response.notification.request.content.userInfo["url"] as? String,
           let notificationURL = URL(string: "https://\(webDomain)\(url)") {
            WebViewManager.shared.handleDeepLink(notificationURL)
        }
        completionHandler()
    }
    
    private func initPushNotifications() {
        let center = UNUserNotificationCenter.current()
        
        center.delegate = self
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
