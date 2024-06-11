//
//  ContentView.swift
//  Pollist
//
//  Created by Matheus Jorge on 5/22/24.
//

import SwiftUI
import WebKit
import StoreKit
import Foundation

struct ContentView: View {
    
    @State private var hasWebViewLoaded = false
    @State private var activeSheet: ActiveSheet?
    @State private var autoShowSubsSheetFromWebViewInSheet = false
    
    enum ActiveSheet: Identifiable {
        case subscription, simpleWebView
        var id: Int {
            hashValue
        }
    }
    
    // MARK: Body
    
    var body: some View {
        ZStack(alignment: .center) {
            // WebView
            WebView(
                url: WebViewManager.shared.webViewURL,
                markWebViewAsLoaded: markWebViewAsLoaded,
                openWebViewInSheet: openWebViewInSheet,
                openSubscriptionSheet: openSubscriptionSheet,
                openManageSubscriptions: openManageSubscriptions
            )
            // Loading View
            if !hasWebViewLoaded {
                Color(.black)
                    .animation(.easeInOut, value: hasWebViewLoaded)
                Image("icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .animation(.easeInOut, value: hasWebViewLoaded)
            }
        }
        // Load webview content
        .onAppear {
            setupNotificationObservers()
            loadWebViewContent()
        }
        // Handle notifications
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeviceTokenUpdated"))) { _ in
            loadWebViewContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeviceTokenUpdateFailed"))) { _ in
            loadWebViewContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDeniedNotifications"))) { _ in
            loadWebViewContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UniversalLinkReceived"))) { _ in
            loadWebViewContent()
        }
        // MARK: Sheets
        .sheet(item: $activeSheet, onDismiss: {
            if activeSheet == nil && autoShowSubsSheetFromWebViewInSheet {
                activeSheet = .subscription
                autoShowSubsSheetFromWebViewInSheet = false
            }
        }) { item in
            switch item {
            case .subscription:
                SubscriptionStoreView(groupID: subGroupID) {
                    VStack {
                        Spacer()
                        
                        Image("icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                        
                        Spacer()
                        
                        HStack {
                            Button("Terms of Service") {
                                DispatchQueue.main.async {
                                    autoShowSubsSheetFromWebViewInSheet = true
                                    WebViewManager.shared.webViewSheetURL = URL(string: "https://pollist.org/tos")!
                                    activeSheet = .simpleWebView
                                }
                            }
                            .padding(0)
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                            
                            Text("and")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Button("Privacy Policy") {
                                DispatchQueue.main.async {
                                    autoShowSubsSheetFromWebViewInSheet = true
                                    WebViewManager.shared.webViewSheetURL = URL(string: "https://pollist.org/privacy")!
                                    activeSheet = .simpleWebView
                                }
                            }
                            .padding(0)
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                    }
                }
                .storeButton(.visible, for: .restorePurchases)
                .subscriptionStoreControlStyle(.prominentPicker)
                .subscriptionStorePickerItemBackground(.ultraThinMaterial)
            case .simpleWebView:
                WebView(
                    url: WebViewManager.shared.webViewSheetURL,
                    markWebViewAsLoaded: markWebViewAsLoaded,
                    openWebViewInSheet: openWebViewInSheet,
                    openSubscriptionSheet: openSubscriptionSheet,
                    openManageSubscriptions: openManageSubscriptions
                )
            }
        }
        // MARK: SwiftUI App Store APIs
        .onInAppPurchaseCompletion { product, result in
            switch result {
            case .success:
                print("onInAppPurchaseCompletion: Purchase completed: \(product.displayName)")
                activeSheet = .subscription
                do {
                    let originalTransactionId = try await product.latestTransaction?.payloadValue.originalID
                    print("onInAppPurchaseCompletion:")
                    print("User id: \(String(describing: WebViewManager.shared.userID))")
                    print("Original transaction id: \(String(describing: originalTransactionId))")
                    
                    if let originalTransactionId = originalTransactionId {
                        // Save subscribed user id
                        UserDefaults.standard.set(WebViewManager.shared.userID, forKey: .subscribedUserID)
                        
                        // Post subscription status
                        await postSubscriptionStatuses([
                            AppStorePayload(
                                productID: product.id,
                                originalID: originalTransactionId,
                                eventType: Product.SubscriptionInfo.RenewalState.subscribed,
                                transaction: product.latestTransaction
                            )]
                        )
                        
                        // Reset webview
                        hasWebViewLoaded = false
                    }
                    else {
                        print("onInAppPurchaseCompletion: Original transaction id is nil, not posting subscription status")
                    }
                }
                catch {
                    print("onInAppPurchaseCompletion: Error getting original transaction id")
                }
                
            case .failure(let error):
                print("onInAppPurchaseCompletion: Purchase failed: \(error)")
            }
        }
        .subscriptionStatusTask(for: subGroupID) { taskState in
            guard let statuses = taskState.value else { return }
            Task {
                let payloads = try statuses.compactMap { status -> AppStorePayload? in
                    
                    let productID = try status.transaction.payloadValue.productID
                    let originalID = try status.transaction.payloadValue.originalID
                    
                    return AppStorePayload(
                        productID: productID,
                        originalID: originalID,
                        eventType: status.state,
                        transaction: status.transaction
                    )
                }
                
                await postSubscriptionStatuses(payloads)
            }
        }
        
    }
    
    // MARK: Setup methods
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("DeviceTokenUpdated"), object: nil, queue: .main) { _ in
            self.loadWebViewContent()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("DeviceTokenUpdateFailed"), object: nil, queue: .main) { _ in
            self.loadWebViewContent()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("UserDeniedNotifications"), object: nil, queue: .main) { _ in
            self.loadWebViewContent()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("UniversalLinkReceived"), object: nil, queue: .main) { _ in
            self.loadWebViewContent()
        }
    }
    
    private func loadWebViewContent() {
        
        if hasWebViewLoaded && WebViewManager.shared.universalURL == nil {
            print("Webview already loaded")
            return
        }
        
        var urlComponents = URLComponents(url: WebViewManager.shared.universalURL ?? WebViewManager.shared.webViewURL, resolvingAgainstBaseURL: false)
        
        let currentQueryItems = urlComponents?.queryItems ?? []
        
        let queryItemSource = URLQueryItem(name: "source", value: "iosWebView")
        
        if let deviceToken = UserDefaults.standard.string(forKey: .deviceToken) {
            let queryItemDeviceToken = URLQueryItem(name: "deviceToken", value: deviceToken)
            urlComponents?.queryItems = currentQueryItems + [queryItemSource, queryItemDeviceToken]
        } else {
            urlComponents?.queryItems = currentQueryItems + [queryItemSource]
        }
        
        if let url = urlComponents?.url {
            WebViewManager.shared.webViewURL = url
        }
        
    }
    
    // MARK: App Store methods
    
    private func postSubscriptionStatuses(_ payloads: [AppStorePayload]) async {
        
        print("post request -> https://pollist.org/api/subscription/device")
        payloads.forEach { payload in
            print("Product ID: \(payload.productID)")
            print("Original Transaction ID: \(payload.originalID)")
            print("Event Type: \(payload.eventType)")
        }
        
        // Ensure valid URL
        guard let url = URL(string: "https://pollist.org/api/subscription/device") else {
            print("Invalid URL")
            return
        }
        
        // Ensure user signed in
        guard WebViewManager.shared.userID != nil else {
            print("userID is nil")
            return
        }
        
        // Ensure signed in user is the subscribed user, allow null in case of app reinstall or other edge cases
        let subscribedUserID = UserDefaults.standard.string(forKey: .subscribedUserID)
        guard subscribedUserID == nil || subscribedUserID == WebViewManager.shared.userID else {
            print("User is not the subscribed user")
            return
        }
        
        // Loop through statuses
        for payload in payloads {
            // Get details
            print("Product ID: \(payload.productID)")
            print("Original Transaction ID: \(payload.originalID)")
            
            // Get event type
            var eventType: String?
            
            switch payload.eventType {
            case .subscribed:
                print("subscribed")
                eventType = "subscribed"
            case .expired:
                print("expired")
                eventType = "expired"
            case .inBillingRetryPeriod:
                print("inBillingRetryPeriod")
                eventType = "inBillingRetryPeriod"
            case .inGracePeriod:
                print("inGracePeriod")
                eventType = "inGracePeriod"
            case .revoked:
                print("revoked")
                eventType = "revoked"
            default:
                print("default")
            }
            
            if eventType == nil {
                print("eventType is nil")
                continue
            }
            
            // Ignore, if we are attempting to subscribe the already subscribed user
             if eventType == "subscribed" && subscribedUserID == WebViewManager.shared.userID {
                 print("User is already subscribed")
                 continue
             }
            
            // Prepare request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "userId": WebViewManager.shared.userID!,
                "originalTransactionId": String(payload.originalID),
                "eventType": eventType!,
                "key": apiKey,
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                print("Failed to encode body: \(error)")
                continue
            }
            
            // Attempt to post subscription, retry once if failed
            for attempt in 1...2 {
                let result = await attemptPostRequest(with: request)
                switch result {
                case .success(let data):
                    print("Subscription successfully posted")
                    do {
                        // Decode the JSON data
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(SubscriptionResponse.self, from: data)
                        
                        // Check subscription state and update UserDefaults
                        if response.state == "subscribed" {
                            UserDefaults.standard.set(response.userId, forKey: .subscribedUserID)
                            UserDefaults.standard.set(response.username, forKey: .subscribedUsername)
                            print("Saved user id \(String(describing: response.userId)) subscribed successfully.")
                        } else if response.state == "unsubscribed" {
                            UserDefaults.standard.removeObject(forKey: .subscribedUserID)
                            UserDefaults.standard.removeObject(forKey: .subscribedUsername)
                            print("Saved user id \(String(describing: response.userId)) unsubscribed successfully.")
                        }
                        
                        return  // Exit function after handling the response successfully
                    } catch {
                        print("JSON decoding error: \(error)")
                    }
                case .failure(let error):
                    print("Attempt \(attempt) failed: \(error)")
                    if attempt == 2 {  // If the second attempt also fails
                        print("Both attempts to post subscription have failed.")
                    }
                }
            }
            
        }
        
    }
    
    private func attemptPostRequest(with request: URLRequest) async -> Result<Data, Error> {
        await withCheckedContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let data = data else {
                    continuation.resume(returning: .failure(URLError(.badServerResponse)))
                    return
                }
                continuation.resume(returning: .success(data))
            }.resume()
        }
    }
    
    // MARK: Delegate methods
    
    private func markWebViewAsLoaded() {
        DispatchQueue.main.async {
            withAnimation { hasWebViewLoaded = true }
            WebViewManager.shared.universalURL = nil
        }
    }
    
    private func openSubscriptionSheet() {
        DispatchQueue.main.async {
            activeSheet = .subscription
        }
    }
    
    private func openManageSubscriptions() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        Task {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene, subscriptionGroupID: subGroupID)
            } catch {
                print("Error showing manage subscriptions: \(error)")
            }
        }
    }
    
    private func openWebViewInSheet(_ url: URL) {
        DispatchQueue.main.async {
            print("Opening webview in sheet: \(url)")
            WebViewManager.shared.webViewSheetURL = url
            activeSheet = .simpleWebView
        }
    }
    
}

struct AppStorePayload {
    var productID: String
    var originalID: UInt64
    var eventType: Product.SubscriptionInfo.RenewalState
    var transaction: VerificationResult<StoreKit.Transaction>?
}

struct SubscriptionResponse: Codable {
    var state: String?
    var userId: String?
    var username: String?
}

#Preview {
    ContentView()
}
