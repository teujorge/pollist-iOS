//
//  CookieManager.swift
//  Pollist
//
//  Created by Matheus Jorge on 6/15/24.
//

import Foundation
import WebKit

class CookieManager {
    static let shared = CookieManager()

    private init() {}

    func synchronizeCookies(to webView: WKWebView, completion: @escaping () -> Void) {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = HTTPCookieStorage.shared.cookies ?? []

        let group = DispatchGroup()

        for cookie in cookies {
            group.enter()
            cookieStore.setCookie(cookie) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }

    func synchronizeCookies(from webView: WKWebView, completion: @escaping () -> Void) {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
            completion()
        }
    }
    
    func clearSessionCookies() {
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
    
}
