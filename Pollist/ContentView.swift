//
//  ContentView.swift
//  Pollist
//
//  Created by Matheus Jorge on 5/22/24.
//

import SwiftUI
import WebKit
import StoreKit

struct ContentView: View {
    
    @State private var hasWebViewLoaded = false
    @State private var showWebViewInSheet = false
    @State private var showSubscriptionSheet = false
    
    // MARK: Body
    
    var body: some View {
        ZStack(alignment: .center) {
            // WebView
            WebView(
                url: LinkManager.shared.webViewURL,
                markWebViewAsLoaded: markWebViewAsLoaded,
                openWebViewInSheet: openWebViewInSheet,
                openSubscriptionSheet: openSubscriptionSheet,
                openManageSubscriptions: openManageSubscriptions
            )
            // Loading View
            if !hasWebViewLoaded {
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
        // Sheets
        .sheet(isPresented: $showSubscriptionSheet) {
            SubscriptionStoreView(groupID: subGroupID)
                .subscriptionStorePickerItemBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showWebViewInSheet) {
            SimpleWebView(url: LinkManager.shared.webViewSheetURL)
        }
//        .id(webViewSheetURL)
        // App Store
        .onInAppPurchaseCompletion { product, result in
            switch result {
            case .success:
                print("ProfileView: Purchase completed: \(product.displayName)")
                showSubscriptionSheet = false
            case .failure(let error):
                print("ProfileView: Purchase failed: \(error)")
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
    }
    
    private func loadWebViewContent() {
        
        if hasWebViewLoaded && LinkManager.shared.universalURL == nil {
            NSLog("Webview already loaded")
            return
        }
        
        var urlComponents = URLComponents(url: LinkManager.shared.universalURL ?? LinkManager.shared.webViewURL, resolvingAgainstBaseURL: false)
        
        let currentQueryItems = urlComponents?.queryItems ?? []
        
        let queryItemSource = URLQueryItem(name: "source", value: "iosWebView")
        
        if let deviceToken = UserDefaults.standard.string(forKey: "deviceToken") {
            let queryItemDeviceToken = URLQueryItem(name: "deviceToken", value: deviceToken)
            urlComponents?.queryItems = currentQueryItems + [queryItemSource, queryItemDeviceToken]
        } else {
            urlComponents?.queryItems = currentQueryItems + [queryItemSource]
        }
        
        if let url = urlComponents?.url {
            LinkManager.shared.webViewURL = url
        }
        
    }
    
    // MARK: Delegate methods
    
    private func markWebViewAsLoaded() {
        DispatchQueue.main.async {
            withAnimation { hasWebViewLoaded = true }
            LinkManager.shared.universalURL = nil
        }
    }
    
    private func openSubscriptionSheet() {
        DispatchQueue.main.async {
            showSubscriptionSheet = true
        }
    }
    
    private func openManageSubscriptions() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        Task {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene, subscriptionGroupID: subGroupID)
            } catch {
                // showSubscriptionSheet = true
                print("Error showing manage subscriptions: \(error)")
            }
        }
    }
    
    private func openWebViewInSheet(_ url: URL) {
        DispatchQueue.main.async {
            print("Opening webview in sheet: \(url)")
            LinkManager.shared.webViewSheetURL = url
            showWebViewInSheet = true
        }
    }
    
}

let subGroupID = "123"

#Preview {
    ContentView()
}
