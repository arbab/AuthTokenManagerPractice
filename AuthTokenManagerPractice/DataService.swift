//
//  DataService.swift
//  MyApp
//
//  Created by Arbab Nawaz on 10/31/26.
//
import Foundation


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
