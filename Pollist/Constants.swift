//
//  Constants.swift
//  Pollist
//
//  Created by Matheus Jorge on 5/27/24.
//

import Foundation

// App Store subscription group ID
let subGroupID = "21491427"

// API key for Next.js /api server authentication
let apiKey = ""

// Enum for UserDefaults keys
enum UserDefaultsKeys: String {
    
    // current user data
    case userID
    case deviceToken
    
    // subscription data
    case subscribedUserID
    case subscribedUsername
}

// Extension for UserDefaults to use type inference with UserDefaultsKeys
extension UserDefaults {
    func set(_ value: Any?, forKey key: UserDefaultsKeys) {
        self.set(value, forKey: key.rawValue)
    }
    
    func value(forKey key: UserDefaultsKeys) -> Any? {
        return self.value(forKey: key.rawValue)
    }
    
    func removeObject(forKey key: UserDefaultsKeys) {
        self.removeObject(forKey: key.rawValue)
    }
    
    func string(forKey key: UserDefaultsKeys) -> String? {
        return self.string(forKey: key.rawValue)
    }
    
    func bool(forKey key: UserDefaultsKeys) -> Bool {
        return self.bool(forKey: key.rawValue)
    }
    
    func integer(forKey key: UserDefaultsKeys) -> Int {
        return self.integer(forKey: key.rawValue)
    }
    
    func float(forKey key: UserDefaultsKeys) -> Float {
        return self.float(forKey: key.rawValue)
    }
    
    func double(forKey key: UserDefaultsKeys) -> Double {
        return self.double(forKey: key.rawValue)
    }
    
    func object(forKey key: UserDefaultsKeys) -> Any? {
        return self.object(forKey: key.rawValue)
    }
}
