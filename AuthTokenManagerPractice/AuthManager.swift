//
//  AuthManager.swift
//  MyApp
//
//  Created by Arbab Nawaz on 10/31/26.
//


import Foundation
import Security

/// Thread-safe Authentication Manager for handling Google OAuth tokens.
actor AuthManager {
    static let shared = AuthManager()
    
    private var accessToken: String? = nil
    private var tokenExpirationDate: Date? = nil
    private let keychainAccount = "com.yourapp.googleRefreshToken"
    
    // Tracks an ongoing refresh operation to merge concurrent requests
    private var refreshTask: Task<String, Error>?
    
    private init() {}
    
    /// Retrieves a valid access token. If expired or close to expiring, it silently refreshes it.
    func getValidAccessToken() async throws -> String {
        // If a refresh is already in progress, await its completion
        if let ongoingTask = refreshTask {
            return try await ongoingTask.value
        }
        
        // Preemptive check: Is the cached token still valid (with a 5-minute safety buffer)?
        if let token = accessToken, let expiry = tokenExpirationDate, expiry.timeIntervalSinceNow > 300 {
            return token
        }
        
        // Token is missing, expired, or near expiry. Start a new refresh task.
        let task = Task { () -> String in
            defer { self.refreshTask = nil } // Clean up when finished
            return try await performSilentRefresh()
        }
        
        self.refreshTask = task
        return try await task.value
    }
    
    /// Executes the actual background OAuth network exchange
    private func performSilentRefresh() async throws -> String {
        guard let refreshToken = loadRefreshTokenFromKeychain() else {
            throw AuthError.missingRefreshToken
        }
        
        var components = URLComponents(string: "https://googleapis.com")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: "YOUR_GOOGLE_CLIENT_://googleusercontent.com"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }
        
        // Handle long-term token expiry / invalidation
        if httpResponse.statusCode == 400 {
            let errorPayload = try? JSONDecoder().decode(GoogleErrorResponse.self, from: data)
            if errorPayload?.error == "invalid_grant" {
                clearStaleCredentials()
                throw AuthError.tokenExpiredPermanently
            }
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError
        }
        
        let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        
        // Update runtime in-memory variables
        self.accessToken = tokenResponse.accessToken
        self.tokenExpirationDate = Date().addingTimeInterval(tokenResponse.expiresIn)
        
        return tokenResponse.accessToken
    }
    
    // MARK: - Keychain Secure Storage Helpers
    
    func saveRefreshToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            // Accessible even when device is locked in background tasks
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly 
        ]
        
        SecItemDelete(query as CFDictionary) // Clear prior entries
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func loadRefreshTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess, let data = dataTypeRef as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
    
    private func clearStaleCredentials() {
        self.accessToken = nil
        self.tokenExpirationDate = nil
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Supporting Types

enum AuthError: Error {
    case missingRefreshToken
    case networkError
    case tokenExpiredPermanently
}

struct GoogleTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

struct GoogleErrorResponse: Decodable {
    let error: String
}