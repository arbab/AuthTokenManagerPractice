//
//  AppCoordinatorView.swift
//  AuthTokenManagerPractice
//
//  Created by Arbab Nawaz on 10/31/26.
//

import SwiftUI

struct AppCoordinatorView: View {
    @State private var appState = AppState()
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                DashboardView()
            } else {
                LoginView(appState: appState)
            }
        }
        // Listen for the global session expiration notice
        .onReceive(NotificationCenter.default.publisher(for: .userSessionDidExpire)) { _ in
            appState.handleSessionExpiry()
        }
    }
}
