//
//  DashboardView.swift
//  AuthTokenManagerPractice
//
//  Created by Arbab Nawaz on 10/31/26.
//
import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Protected App Content Dashboard")
                    .font(.headline)
                
                Button("Simulate Network Call (401 Expiry)") {
                    // Triggers the notification to prove the coordinator switches views automatically
                    NotificationCenter.default.post(name: .userSessionDidExpire, object: nil)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .navigationTitle("Main App")
        }
    }
}
