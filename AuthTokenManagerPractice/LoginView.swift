//
//  LoginView.swift
//  AuthTokenManagerPractice
//
//  Created by Arbab Nawaz on 10/31/26.
//
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State var appState: AppState
    @State private var isAuthenticating = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 10) {
                Text("Welcome Back")
                    .font(.largeTitle)
                    .bold()
                Text("Your session expired or you need to sign in.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            Button(action: { triggerGoogleLogin() }) {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Sign in with Google")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isAuthenticating)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - OAuth Re-Authentication Trigger
    private func triggerGoogleLogin() {
        isAuthenticating = true
        
        // Define your OAuth URL components including recovery elements
        var components = URLComponents(string: "https://google.com")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: "YOUR_GOOGLE_CLIENT_://googleusercontent.com"),
            URLQueryItem(name: "redirect_uri", value: "com.yourapp.bundleid:/oauth2callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://googleapis.com"),
            // Essential keys for offline sync and forced recovery:
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        guard let authURL = components.url else { return }
        let callbackScheme = "com.yourapp.bundleid"
        
        // Initialize Apple's native secure web browser engine
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { callbackURL, error in
            isAuthenticating = false
            
            guard error == nil, let successURL = callbackURL else {
                // User cancelled or auth failed
                return
            }
            
            // Extract the 'code' parameter from the redirected query
            if let urlComponents = URLComponents(url: successURL, resolvingAgainstBaseURL: true),
               let authCode = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value {
                
                Task {
                    // Send this code to your backend or handle direct token exchange 
                    // then save your new refresh_token securely:
                    // await AuthManager.shared.saveRefreshToken(receivedRefreshToken)
                    
                    await MainActor.run {
                        withAnimation {
                            appState.isAuthenticated = true
                        }
                    }
                }
            }
        }
        
        // Provide the context window anchoring for iPad / modern iOS presentations
        session.presentationContextProvider = PresentationAnchorWindow.shared
        session.start()
    }
}

// Window contextualizer requirement for ASWebAuthenticationSession
class PresentationAnchorWindow: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationAnchorWindow()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
