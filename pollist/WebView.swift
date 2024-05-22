//
//  WebView.swift
//  pollist
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
        let webView = WKWebView()
        
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
        webView.customUserAgent = "Mozilla/5.0 (Linux; Android 8.0; Pixel 2 Build/OPD3.170816.012) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Mobile Safari/537.36"
        
        context.coordinator.webView = webView
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        DispatchQueue.main.async {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
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
            
            // Ensure that there is no target frame (indicating it might be an external link)
            guard navigationAction.targetFrame == nil else {
                decisionHandler(.allow)
                return
            }

            guard let url = navigationAction.request.url,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let host = components.host else {
                decisionHandler(.allow)
                return
            }

            NSLog("Host: \(host)")

            if host == "pollist.org" && components.queryItems?.contains(where: { $0.name == "target" && $0.value == "_blank" }) == true {
                NSLog("Open in default browser")
                UIApplication.shared.open(url)
            } else if host == "twitter.com" || host == "api.whatsapp.com" {
                NSLog("Open in default browser")
                UIApplication.shared.open(url)
            } else if host == "pollist.org" && url.path == "/subscribe" {
                NSLog("Open purchase subscription")
                let userId = components.queryItems?.first(where: { $0.name == "client_reference_id" })?.value
                let productId = components.queryItems?.first(where: { $0.name == "product_id" })?.value
                print("User ID: \(userId ?? "nil")")
                print("Product ID: \(productId ?? "nil")")
                parent.openSubscriptionSheet()
            } else if host == "pollist.org" && url.path == "/subscription" {
                NSLog("Open manage subscription")
                parent.openManageSubscriptions()
            } else {
                NSLog("Open link in bottom sheet")
                parent.openWebViewInSheet(url)
            }

            // Cancel the default handling of this URL to enforce our custom behavior
            decisionHandler(.cancel)
        }
        
        @objc func refreshWebView() {
            webView?.reload()
        }
    }
}
