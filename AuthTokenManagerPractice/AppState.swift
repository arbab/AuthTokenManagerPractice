//
//  AppState.swift
//  AuthTokenManagerPractice
//
//  Created by Arbab Nawaz on 10/31/26.
//


import SwiftUI
import AuthenticationServices
import Observation
import Combine

@MainActor
@Observable
class AppState {
    var isAuthenticated: Bool = false
    
    init() {
        // Check if a token exists in the keychain on boot to skip login
        // (You can check this by exposing a quick boolean from AuthManager)
    }
    
    func handleSessionExpiry() {
        withAnimation {
            self.isAuthenticated = false
        }
    }
}
