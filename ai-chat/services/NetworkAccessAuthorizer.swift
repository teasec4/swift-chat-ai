//
//  NetworkAccessAuthorizer.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/14/26.
//

import Foundation

@MainActor
protocol NetworkAccessAuthorizing: AnyObject {
    var hasUserApproval: Bool { get }

    func approveNetworkAccess()
    func prepareForNetworkUse() async throws
}

@MainActor
final class NetworkAccessAuthorizer: NetworkAccessAuthorizing {
    private let defaults: UserDefaults
    private let approvalKey: String
    private let probeURL: URL
    private let urlSession: URLSession

    init(
        defaults: UserDefaults = .standard,
        approvalKey: String = "hasApprovedNetworkAccess",
        probeURL: URL = URL(string: "https://api.deepseek.com")!,
        urlSession: URLSession = .shared
    ) {
        self.defaults = defaults
        self.approvalKey = approvalKey
        self.probeURL = probeURL
        self.urlSession = urlSession
    }

    var hasUserApproval: Bool {
        defaults.bool(forKey: approvalKey)
    }

    func approveNetworkAccess() {
        defaults.set(true, forKey: approvalKey)
    }

    func prepareForNetworkUse() async throws {
        guard hasUserApproval else {
            throw NetworkAccessError.needsApproval
        }

        var request = URLRequest(url: probeURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8

        do {
            let (_, response) = try await urlSession.data(for: request)

            guard response is HTTPURLResponse else {
                throw NetworkAccessError.unavailable
            }
        } catch let error as NetworkAccessError {
            throw error
        } catch {
            throw NetworkAccessError.unavailable
        }
    }
}

enum NetworkAccessError: LocalizedError, Equatable {
    case needsApproval
    case unavailable

    var errorDescription: String? {
        switch self {
        case .needsApproval:
            "Allow network access before starting an AI conversation."
        case .unavailable:
            "Network access is unavailable. Allow network access for this app and check your connection."
        }
    }
}
