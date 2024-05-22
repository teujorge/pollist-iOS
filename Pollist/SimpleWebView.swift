//
//  SimpleWebView.swift
//  Pollist
//
//  Created by Matheus Jorge on 5/22/24.
//

import SwiftUI
import WebKit

struct SimpleWebView: UIViewRepresentable {
    
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        
        // Set background color
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        // Disable link preview
        webView.allowsLinkPreview = false

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        DispatchQueue.main.async {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
}
