//
//  ChatMessage.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let text: String
    let isUser: Bool
    let timestamp: Date
    var artifact: ChatArtifact?

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ChatArtifact: Equatable {
    let filePath: String
    let fileType: String
}

extension Date {
    var chatTimestampLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
}

enum GwenDateParsing {
    static func parse(_ isoString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return date
        }
        
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: isoString) ?? Date()
    }
}
