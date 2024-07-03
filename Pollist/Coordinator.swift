//
//  Coordinator.swift
//  Pollist
//
//  Created by Matheus Jorge on 6/15/24.
//

import Foundation
import WebKit
import AuthenticationServices

class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, ASWebAuthenticationPresentationContextProviding {
    
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
        
        // Synchronize cookies back to shared storage
        CookieManager.shared.synchronizeCookies(from: webView) {}
    }
    
    // Handle webview navigation links
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        // Ensure that the URL is valid
        guard let url = navigationAction.request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            decisionHandler(.allow)
            return
        }
        
        print("HOST: \(host)")
        
//        if host.contains("accounts.google") || host.contains("accounts.youtube") {
//            // Initiate ASWebAuthenticationSession for secure OAuth handling
//            print("Initiate ASWebAuthenticationSession")
//            let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: nil) { callbackURL, error in
//                
//                print("Process the callback URL: \(String(describing: callbackURL))")
//         
//                // Handle the response from the authentication session
//                if let error = error {
//                    print("Authentication error: \(error.localizedDescription)")
//                }
//                else if let callbackURL = callbackURL {
//                    // Process the callback URL
//                    print("Process the callback URL: \(callbackURL)")
//                    if callbackURL.host == "clerk.pollist.org" {
//                        // Terminate the session and pass information
//                        DispatchQueue.main.async {
//                            // Extract the relevant data from callbackURL if necessary
//                            // Direct the main WebView to proceed to the correct page or refresh with the auth info
//                            UIApplication.shared.open(callbackURL)
//                        }
//                        // Prevent the ASWebAuthenticationSession from proceeding to open the URL
//                        return
//                    }
//                }
//            }
//            print("Start auth session")
//            authSession.presentationContextProvider = self
//            authSession.prefersEphemeralWebBrowserSession = true
//            authSession.start()
//            
//            decisionHandler(.cancel)
//            return
//        }
        
        // Ensure that there is no target frame (indicating it might be an internal link)
        guard navigationAction.targetFrame == nil else {
            decisionHandler(.allow)
            return
        }
        
        if host == webDomain && components.queryItems?.contains(where: { $0.name == "target" && $0.value == "_blank" }) == true {
            print("Open in default browser")
            UIApplication.shared.open(url)
        } else if host == "twitter.com" || host == "api.whatsapp.com" {
            print("Open in default browser")
            UIApplication.shared.open(url)
        } else if host == webDomain && url.path == "/subscribe" {
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
        } else if host == webDomain && url.path == "/subscription" {
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
                CookieManager.shared.clearSessionCookies()
                WebViewManager.shared.userID = nil
            } else {
                WebViewManager.shared.userID = messageBody
            }
        }
    }
    
    @objc func refreshWebView() {
        webView?.reload()
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> UIWindow {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            fatalError("No key window found")
        }
        return keyWindow
    }

}

