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
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        DispatchQueue.main.async {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
    
    private func cleanWebViewData() {
        let websiteDataTypes = Set([WKWebsiteDataTypeCookies])
        let dataStore = WKWebsiteDataStore.default()
        
        dataStore.fetchDataRecords(ofTypes: websiteDataTypes) { records in
            // Filter out cookies to delete (containing "google" but not "accounts.google.com")
            let recordsToDelete = records.filter { record in
                record.displayName.contains("google") && !record.displayName.contains("accounts.google.com")
            }
            
            // Remove the filtered cookies
            dataStore.removeData(ofTypes: websiteDataTypes, for: recordsToDelete) {
                recordsToDelete.forEach { record in
                    print("Cleared cookies for: \(record.displayName)")
                }
            }
        }
    }
    
    private func showAlertIfNeeded(completion: @escaping () -> Void) {
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
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        
        var parent: WebView
        var webView: WKWebView?
        var refreshControl: UIRefreshControl?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        // Handle webview navigation finish
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            refreshControl?.endRefreshing()
            parent.markWebViewAsLoaded()
        }
        
        // Handle webview navigation links
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            print("Handle navigation action")
            
            // Ensure that the URL is valid
            guard let url = navigationAction.request.url,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let host = components.host else {
                decisionHandler(.allow)
                return
            }
            
            // Ensure that there is no target frame (indicating it might be an internal link)
            guard navigationAction.targetFrame == nil else {
                decisionHandler(.allow)
                return
            }
            
            print("Host: \(host)")
            
            if host == "pollist.org" && components.queryItems?.contains(where: { $0.name == "target" && $0.value == "_blank" }) == true {
                print("Open in default browser")
                UIApplication.shared.open(url)
            } else if host == "twitter.com" || host == "api.whatsapp.com" {
                print("Open in default browser")
                UIApplication.shared.open(url)
            } else if host == "pollist.org" && url.path == "/subscribe" {
                print("Open purchase subscription")
                let userID = components.queryItems?.first(where: { $0.name == "client_reference_id" })?.value
                let productID = components.queryItems?.first(where: { $0.name == "product_id" })?.value
                print("User ID: \(userID ?? "nil")")
                print("Product ID: \(productID ?? "nil")")
                
                if userID != nil && userID != WebViewManager.shared.userID {
                    WebViewManager.shared.userID = userID
                }
                parent.showAlertIfNeeded() {
                    self.parent.openSubscriptionSheet()
                }
            } else if host == "pollist.org" && url.path == "/subscription" {
                print("Open manage subscription")
                parent.showAlertIfNeeded() {
                    self.parent.openManageSubscriptions()
                }
            } else {
                print("Open link in bottom sheet")
                parent.openWebViewInSheet(url)
            }
            
            // Cancel the default handling of this URL to enforce our custom behavior
            decisionHandler(.cancel)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "userListener", let messageBody = message.body as? String {
                print("userListener message from web: \(messageBody)")
                if messageBody.isEmpty {
                    parent.cleanWebViewData()
                    WebViewManager.shared.userID = nil
                } else {
                    WebViewManager.shared.userID = messageBody
                }
            }
        }
        
        @objc func refreshWebView() {
            webView?.reload()
        }
    }
}
