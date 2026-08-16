//
//  GwenEvent.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 14/08/2026.
//

import Foundation

struct GwenPayloadWrapper<Payload: Decodable>: Decodable {
    let payload: Payload
}

enum InputMode: String, Codable {
    case voice
    case text
}

struct GwenEventEnvelope: Decodable {
    let type: String
    let timestamp: String
}

struct StateChangedPayload: Decodable {
    let state: GwenState
}

struct ChatMessagePayload: Decodable {
    let id: String
    let sessionId: String
    let role: String
    let displayText: String
    let speechText: String?
    let timestamp: String
    let attachment: ChatAttachmentPayload?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case role
        case displayText = "display_text"
        case speechText = "speech_text"
        case timestamp
        case attachment
    }
}

struct ChatAttachmentPayload: Decodable {
    let filePath: String
    let fileType: String
    let filename: String

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case fileType = "file_type"
        case filename
    }
}

struct ModeChangedPayload: Decodable {
    let mode: InputMode
    let source: String
}

struct ModelTierChangedPayload: Decodable {
    let tier: GwenMode
    let source: String
}

struct FileReadyPayload: Decodable {
    let sessionId: String
    let filePath: String
    let fileType: String
    let messageId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case filePath = "file_path"
        case fileType = "file_type"
        case messageId = "message_id"
    }
}

struct SessionStartedPayload: Decodable {
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
    }
}

struct ErrorPayload: Decodable {
    let message: String
    let recoverable: Bool
}

struct GwenInboundEvent: Encodable {
    let type: String
    let payload: [String: String]
}

enum InboundEventBuilder {
    static func sendText(_ text: String) -> GwenInboundEvent {
        GwenInboundEvent(type: "send_text", payload: ["text": text])
    }

    static func setModelTier(_ tier: GwenMode) -> GwenInboundEvent {
        GwenInboundEvent(type: "set_model_tier", payload: ["tier": tier.rawValue])
    }

    static func setInputMode(_ mode: InputMode) -> GwenInboundEvent {
        GwenInboundEvent(type: "set_input_mode", payload: ["mode": mode.rawValue])
    }
}
