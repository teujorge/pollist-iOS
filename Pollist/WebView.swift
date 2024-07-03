//
//  WebView.swift
//  Pollist
//
//  Created by Matheus Jorge on 5/22/24.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {

    let url: URL
    let markWebViewAsLoaded: () -> Void
    let openWebViewInSheet: (URL) -> Void
    let openSubscriptionSheet: () -> Void
    let openManageSubscriptions: () -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        // Setup
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        userContentController.add(context.coordinator, name: "userListener")
        config.userContentController = userContentController
        
        // Use the default data store to share cookies
        config.websiteDataStore = .default()
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        // Set background color
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        // Set navigation delegate
        webView.navigationDelegate = context.coordinator
        
        // Disable link preview
        webView.allowsLinkPreview = false
        
        // Enable forward and back navigation
        webView.allowsBackForwardNavigationGestures = true
        
        // Enable swipe down to refresh page
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.refreshWebView), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)
        context.coordinator.refreshControl = refreshControl
        
        // Set user agent for clerk auth
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1"
        
        context.coordinator.webView = webView
        
        // Synchronize cookies from shared storage to WKWebView
        CookieManager.shared.synchronizeCookies(to: webView) {
            let request = URLRequest(url: self.url)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        DispatchQueue.main.async {
            let request = URLRequest(url: self.url)
            uiView.load(request)
        }
    }
    
    func showAlertIfNeeded(completion: @escaping () -> Void) {
        guard let userID = WebViewManager.shared.userID,
              let savedUserID = UserDefaults.standard.string(forKey: .subscribedUserID),
              userID != savedUserID else {
            completion()  // Perform the completion action if no alert is needed
            return
        }
        
        let savedUsername = UserDefaults.standard.string(forKey: .subscribedUsername)
        var message: String
        
        if savedUsername == nil {
            message = "This Apple ID has already subscribed through another account."
        } else {
            message = "This Apple ID has already subscribed through the account '\(savedUsername!)'."
        }
        
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Subscription Alert", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completion()  // Perform the completion action after alert dismissal
            })
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                rootViewController.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
}
