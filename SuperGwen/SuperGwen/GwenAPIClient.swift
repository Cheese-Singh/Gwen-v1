//
//  GwenApiClient.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 14/08/2026.
//

import Foundation

struct SessionSummary: Decodable, Identifiable {
    let sessionId: String
    let title: String?
    let startedAt: String
    let lastActiveAt: String

    var id: String { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case title
        case startedAt = "started_at"
        case lastActiveAt = "last_active_at"
    }
}

struct SessionDetail: Decodable {
    let messages: [ChatMessagePayload]
    let artifacts: [SessionArtifact]
}

struct SessionArtifact: Decodable, Identifiable {
    let id: String
    let messageId: String?
    let kind: String
    let filename: String
    let filePath: String?
    let content: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, filename, content
        case messageId = "message_id"
        case filePath = "file_path"
    }
}

struct UploadResponse: Decodable {
    let filePath: String
    let fileType: String

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case fileType = "file_type"
    }
}

enum GwenAPIError: LocalizedError {
    case server(status: Int, body: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let status, let body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Server returned status \(status)" : "Server error \(status): \(trimmed)"
        case .invalidResponse:
            return "Received an unexpected response from the server."
        }
    }
}

final class GwenAPIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default)
    }

    /// Every call funnels through this so a 4xx/5xx never gets silently
    /// force-decoded as a success payload -- that used to surface as a
    /// confusing JSON decode error instead of the actual server message.
    private func validated(_ data: Data, _ response: URLResponse) throws -> Data {
        guard let http = response as? HTTPURLResponse else {
            throw GwenAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GwenAPIError.server(status: http.statusCode, body: body)
        }
        return data
    }

    func listSessions() async throws -> [SessionSummary] {
        let url = baseURL.appendingPathComponent("sessions")
        let (data, response) = try await session.data(from: url)
        let validData = try validated(data, response)
        return try JSONDecoder().decode([SessionSummary].self, from: validData)
    }

    func loadSession(id: String) async throws -> SessionDetail {
        let url = baseURL.appendingPathComponent("sessions/\(id)")
        let (data, response) = try await session.data(from: url)
        let validData = try validated(data, response)
        return try JSONDecoder().decode(SessionDetail.self, from: validData)
    }

    func startNewSession() async throws -> String {
        let url = baseURL.appendingPathComponent("sessions/new")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        let validData = try validated(data, response)
        struct Response: Decodable {
            let sessionId: String
            enum CodingKeys: String, CodingKey { case sessionId = "session_id" }
        }
        return try JSONDecoder().decode(Response.self, from: validData).sessionId
    }

    func uploadFile(fileURL: URL) async throws -> UploadResponse {
        let endpoint = baseURL.appendingPathComponent("upload")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")

        let (data, response) = try await session.data(for: request)
        let validData = try validated(data, response)
        return try JSONDecoder().decode(UploadResponse.self, from: validData)
    }

    func setModelTier(_ tier: GwenMode) async throws {
        let url = baseURL.appendingPathComponent("mode/tier")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["tier": tier.rawValue])
        let (data, response) = try await session.data(for: request)
        _ = try validated(data, response)
    }
}
