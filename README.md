#  Auth Token and Refresh

When a refresh token expires because an app has been offline for too long, you cannot silently refresh it. You must trigger a re-authentication flow (such as an OAuth2 interactive login) so the user can log in again. [1] (https://www.reddit.com/r/reactnative/comments/rl28xe/how_to_handle_access_token_refresh_to_keep_user/), [2] (https://www.oauth.com/oauth2-servers/making-authenticated-requests/refreshing-an-access-token/), [3] (https://medium.com/@prakash_ranjan/handling-jwt-token-expiration-and-re-authentication-in-android-kotlin-441838e5ce0a), [4] (https://github.com/orgs/community/discussions/184563)

Standard Recovery Steps

1. Catch the Error:
    • Sending a refresh request with an expired token to the provider's token endpoint (e.g., using grant_type=refresh_token) returns an error like invalid_grant or 403 Forbidden / 401 Unauthorized. [1] (https://developer.atlassian.com/cloud/oauth/getting-started/refresh-tokens/), [2] (https://www.oauth.com/oauth2-servers/making-authenticated-requests/refreshing-an-access-token/), [3] (https://www.reddit.com/r/reactnative/comments/rl28xe/how_to_handle_access_token_refresh_to_keep_user/)
2. Clear Stale Credentials:
    • Wipe the expired access token, the expired refresh token, and any local session state from secure storage to avoid looping. [1] (https://github.com/orgs/community/discussions/184563)
3. Prompt Re-Authentication:
    • Redirect the user to the provider's login/authorization screen (or show a native login prompt) to obtain a fresh authorization code or token pair.
    • Ensure your initial authorization request includes any required offline or extended access scopes (such as offline_access) if you need background capabilities. [1] (https://stackoverflow.com/questions/54332300/how-do-i-request-a-new-refresh-token-when-the-last-one-expired), [2] (https://www.oauth.com/oauth2-servers/making-authenticated-requests/refreshing-an-access-token/), [3] (https://github.com/orgs/community/discussions/184563), [4] (https://www.reddit.com/r/reactnative/comments/rl28xe/how_to_handle_access_token_refresh_to_keep_user/), [5] (https://developer.atlassian.com/cloud/oauth/getting-started/refresh-tokens/)

Special Exceptions & Platform Mechanisms

• Grace/Recovery Windows (Some APIs):
    • Platforms like Shopify Community or certain payment APIs (e.g., Clover Docs) offer a short recovery window (such as up to 30 days) where an immediately preceding (older) refresh token can be exchanged once if a network or storage failure caused you to miss the latest rotation. Once that window passes or the token is permanently expired, recovery fails. [1] (https://docs.clover.com/dev/docs/refresh-access-tokens), [2] (https://community.shopify.dev/t/update-more-resilient-refresh-token-recovery-for-expiring-offline-tokens/37282)
• Sliding Lifetimes & Activity Rules:
    • Some providers extend refresh tokens automatically every time you use them (e.g., DocuSign Stack Overflow), while others enforce a hard ceiling (such as 90 days of total inactivity or a fixed single-page app limit) after which the token dies regardless of past use. [1] (https://learn.microsoft.com/en-us/entra/identity-platform/refresh-tokens), [2] (https://learn.microsoft.com/en-us/answers/questions/2244843/the-refresh-token-has-expired-due-to-inactivity-ho), [3] (https://community.shopify.dev/t/update-more-resilient-refresh-token-recovery-for-expiring-offline-tokens/37282)
You can read more about standard error handling patterns in the OAuth 2.0 Simplified Guide. [1] (https://www.oauth.com/oauth2-servers/making-authenticated-requests/refreshing-an-access-token/)
If you share which authentication provider or API you are integrating with (e.g., Google, Microsoft Entra, Shopify, custom backend), I can give you the exact error codes and recovery parameters for that system.


### Example Google Login

When implementing Google Login, if your app stays offline for too long, the refresh token will eventually expire or be invalidated by Google. Because a completely dead refresh token cannot fetch new credentials programmatically, your only recourse is to force the user through an interactive re-authentication flow to issue a brand-new token pair.

1. Why Google Invalidated Your Token

Google typically throws an invalid_grant error with an accompanying description ("Token has been expired or revoked") during your token refresh request for a few specific reasons related to long-term inactivity:
• 6-Month Inactivity Timeout: Google automatically revokes refresh tokens that have not been used for six consecutive months.
• App is still in "Testing" Status: If your project's OAuth consent screen is set to Testing in the Google Cloud Console, tokens automatically expire after exactly 7 days, regardless of use. Moving the app to Production status fixes this constraint.
• Password Resets: If your OAuth scopes include Gmail scopes, the user resetting their Google Account password immediately revokes all existing refresh tokens.

2. The Implementation Fix

To recover, you must clear the bad token from your database or client storage and prompt the user to log in again. However, because they have already authorized your app in the past, a standard Google login link may auto-approve the user without sending a new refresh token back to your server.
You must pass two critical parameters to the Google OAuth 2.0 authorization endpoint (https://google.com) during re-authentication to ensure you get a new refresh token:
http
https://google.com?
  client_id=YOUR_CLIENT_ID&
  redirect_uri=YOUR_REDIRECT_URI&
  response_type=code&
  scope=https://googleapis.com&
  access_type=offline&
  prompt=consent
Use code with caution.

Parameter    Required Value    Why It Matters
access_type    offline    Explicitly tells Google your application needs to access data when the user is not present, prompting Google to include a refresh_token in the initial code exchange.
prompt    consent    Crucial for recovery. Forces the user to see the consent screen again. Without this, Google remembers their past approval, redirects instantly, and omits the new refresh token from the payload.

For a step-by-step breakdown of how to map these responses safely, check out the Nylas invalid_grant Troubleshooting Guide.
Are you building a web application (Node, Python, Go) or a client-side/mobile app (iOS, Android, SPA)? Providing this will let me give you the exact code snippet or SDK configuration required to inject the prompt=consent parameter safely.



### Visual diagram 
*Visual diagram of handling general login and auth token, refresh token and the scenarios like for example, normal refresh, refresh after expiry, offline support.*

+-----------------------------------------------------------------------------------+

|                              1. INITIAL LOGIN FLOW                                |
+-----------------------------------------------------------------------------------+
[ User ] --------( Submits Credentials / Google Login )--------> [ Client App ]
                                                                      |
    <--- ( Returns Access Token + Refresh Token + Expiry ) -----------+
+-----------------------------------------------------------------------------------+

|                    2. NORMAL OPERATION & SILENT REFRESH (Online)                  |
+-----------------------------------------------------------------------------------+
[ Client App ] --------( API Request + Access Token )--------> [ Resource Server ]
                                                                      |
    <----------------- ( Returns 200 OK Data ) -----------------------+

       === [ Access Token Expires after 1 Hour ] ===

[ Client App ] --------( POST: refresh_token )--------------> [ OAuth Provider ]
                                                                      |
    <--- ( Returns NEW Access Token [+ Optional Rotated Refresh] ) ---+
+-----------------------------------------------------------------------------------+

|               3. OFFLINE SUPPORT SCENARIO (App closes / goes offline)             |
+-----------------------------------------------------------------------------------+
[ Client App ] --( Saves Refresh Token to Encrypted Secure Storage ) 
                               |
                   [ App completely closed / device offline ]
                               |
[ Client App ] --( Wakes up online later -> Checks Storage -> Validates Token )
+-----------------------------------------------------------------------------------+

|            4. REFRESH AFTER LONG-TERM INACTIVITY EXPIRY (Google Specific)         |
+-----------------------------------------------------------------------------------+
[ Client App ] --------( POST: refresh_token )--------------> [ OAuth Provider ]
                                                                      |
    <--- ( Returns 400 Bad Request / "invalid_grant" ) ---------------+
                               |
         [ Client Wipes Stale Tokens from Secure Storage ]
                               |
[ Client App ] --------( Force Login Window via prompt=consent )----> [ User Screen ]
                                                                      |
    <--- ( Explicitly Grants Consent & Re-Authenticates ) ------------+
                               |
    <--- ( Issues Brand-New Access + Refresh Token Pair ) ------------+

Breakdown of the Architectural Scenarios

1. Initial Login: The client application requests offline access (access_type=offline). Google issues a short-lived access_token (usually valid for 1 hour) and a long-lived refresh_token.
2. Normal Silent Refresh: While the app is active and online, it monitors the lifetime of the access token. When it expires, the app hits the token endpoint in the background without disturbing the user.
3. Offline Support: The refresh token is safely isolated in secure hardware storage (like Keychain, Keystore, or an encrypted server database). When the app restarts or regains internet connectivity days later, it immediately attempts to use this stored token to resume the session.
4. Refresh After Long-Term Expiry: If the app has been offline for months (or 7 days if the app status is still in Google's "Testing" tier), the OAuth provider rejects the request with an invalid_grant payload. The app must aggressively handle this failure by flushing local caches and showing the interactive authorization prompt using prompt=consent to guarantee a brand-new token pair.


### Handling the Normal Silent Refresh flow

In iOS applications, handling the Normal Silent Refresh flow involves executing background network requests, securely managing cryptographic material, and intercepting API calls seamlessly without interrupting the user.

The Core Architectural Pattern

In iOS, you should never refresh a token based on an arbitrary timer. Instead, use a reactive approach leveraging an OAuth Token Interceptor or an Adapter Pattern.
The app attempts a standard API request. If the Access Token is expired, the network layer catches the failure, pauses incoming API requests, fetches a new token, and retries the original request seamlessly.

Step-by-Step iOS Lifecycle


1. Token Storage Isolation

• Secure Enclave / Keychain: The refresh_token must be stored securely using iOS Keychain Services. Access it using the kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly protection space to ensure background operations can access it even if the device screen is locked.
• In-Memory Cache: Keep the short-lived access_token in an in-memory manager object (e.g., AuthManager). Never persist the access token to disk to minimize attack surface.

2. The Network Interceptor Dance

Most modern iOS apps use Alamofire (via RequestInterceptor) or native URLSession (via a custom asynchronous wrapper or URLSessionDataDelegate). 
Here is how the sequence occurs under the hood:

[ Your API Service ]             [ Interceptor / AuthManager ]            [ Google/OAuth API ]

         |                                     |                                   |
         | ---- 1. Request Data -------------> |                                   |
         |                                     | -- 2. Check Expiry Window ------> |
         |                                     |    (Tokens valid for 1 hour;      |
         |                                     |     refresh if < 5 mins left)     |
         |                                     |                                   |
         |                                     | == STATUS: TOKEN EXPIRED ==       |
         |                                     |                                   |
         |                                     | ---- 3. POST /token (Refresh) --> |
         |                                     | <--- 4. New Access Token -------- |
         |                                     |                                   |
         | <--- 5. Retries original request --- |                                   |
         |        with fresh Access Token      |                                   |

3. Concurrency & Request Queueing

If your app loads a dashboard, it might fire 5 different API requests simultaneously. If your access token is expired, you must prevent Token Refresh Storms (sending 5 separate refresh requests to Google).
• The Lock Mechanism: The AuthManager must utilize Swift Concurrency (actor) or a dispatch queue barrier.
• Suspending Requests: The first request detects the expired token, triggers the refresh, and sets a isRefreshing flag.
• Queueing: The remaining 4 incoming requests are placed in an array of completion handlers or suspended via Swift CheckedContinuation.
• The Flush: Once the single refresh network call finishes, the new token is broadcast to all waiting requests, and they proceed concurrently.

Strategic iOS Design Considerations


Feature    iOS Implementation Choice    Crucial Detail
Token Buffer Window    Hardcoded Time Check    Don't wait for a 401 Unauthorized from the server. Check if the cached token's expiry timestamp is < 5 minutes from Date(). Refresh it preemptively before making the call.
Thread Safety    Swift Actors    Mark your AuthManager as an actor. This guarantees mutually exclusive access to token states across threads natively in modern Swift.
Background Refresh    Background Tasks API    If your app receives a background push notification (Silent Push), you can wake up the app, securely grab the refresh token from Keychain, perform a silent network refresh, and update your data cache within your allotted background execution window.


### The Implementation

Here is the complete, thread-safe implementation of an iOS Authentication Manager using a Swift actor and URLSession.
This design pattern uses an active preemptive buffer check (refreshing if the token is within 5 minutes of expiring) and a request queuing system. By using a Swift actor, it natively guarantees that multiple simultaneous API calls will wait for a single, shared token refresh process instead of triggering a "token refresh storm."

The Implementation

```swift
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
```

How to use it in your Network Layer

When calling your backend API services, you just wrap the target URLSession request call by awaiting getValidAccessToken(). If the token is valid, it returns instantly. If a refresh is required, the execution suspends natively until the network cycle fulfills.
```swift
class DataService {
    func fetchDashboardData() async throws -> Data {
        let url = URL(string: "https://yourserver.com")!
        var request = URLRequest(url: url)
        
        do {
            // Await safely. If 3 requests hit this concurrently, 
            // the actor ensures only ONE network token refresh happens.
            let validToken = try await AuthManager.shared.getValidAccessToken()
            request.setValue("Bearer \(validToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            // Handle standard data processing...
            return data
            
        } catch AuthError.tokenExpiredPermanently {
            // Post an internal notification or handle routing back to the Login UI screen
            await MainActor.run {
                NotificationCenter.default.post(name: .userSessionDidExpire, object: nil)
            }
            throw AuthError.tokenExpiredPermanently
        }
    }
}

extension Notification.Name {
    static let userSessionDidExpire = Notification.Name("userSessionDidExpire")
}
```
