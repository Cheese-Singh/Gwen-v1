//
//  GwenViewModel.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 16/07/2026.
//

import SwiftUI

@Observable
class GwenViewModel {

    var currentState: GwenState = .idle
    var inputMode: InputMode = .voice
    var selectedMode: GwenMode = .regular
    var prompt: String = ""
    var messages: [ChatMessage] = []
    var sessions: [SessionSummary] = []
    var currentSessionId: String?
    var isConnected: Bool = false
    var lastErrorMessage: String?

    var isAwaitingReply: Bool = false

    private let wsClient: GwenWebSocketClient
    private let apiClient: GwenAPIClient

    private var seenMessageIds: Set<String> = []

    private var pendingArtifacts: [String: ChatArtifact] = [:]

    init(
        wsURL: URL = URL(string: "ws://localhost:8000/ws")!,
        apiBaseURL: URL = URL(string: "http://localhost:8000")!
    ) {
        self.wsClient = GwenWebSocketClient(url: wsURL)
        self.apiClient = GwenAPIClient(baseURL: apiBaseURL)

        wsClient.onEvent = { [weak self] envelope, rawData in
            self?.handle(envelope: envelope, rawData: rawData)
        }
        wsClient.onConnect = { [weak self] in
            self?.isConnected = true
        }
        wsClient.onDisconnect = { [weak self] in
            self?.isConnected = false
        }
    }

    func connect() {
        wsClient.connect()
    }

    func disconnect() {
        wsClient.disconnect()
        isConnected = false
    }

    private func handle(envelope: GwenEventEnvelope, rawData: Data) {
        switch envelope.type {
        case "state_changed":
            if let payload = decodePayload(StateChangedPayload.self, from: rawData, eventType: envelope.type) {
                currentState = payload.state
                isAwaitingReply = (payload.state == .thinking)
            }

        case "chat_message":
            if let payload = decodePayload(ChatMessagePayload.self, from: rawData, eventType: envelope.type) {
                appendIfNew(payload)
            }

        case "mode_changed":
            if let payload = decodePayload(ModeChangedPayload.self, from: rawData, eventType: envelope.type) {
                inputMode = payload.mode
            }

        case "model_tier_changed":
            if let payload = decodePayload(ModelTierChangedPayload.self, from: rawData, eventType: envelope.type) {
                selectedMode = payload.tier
            }

        case "file_ready":
            if let payload = decodePayload(FileReadyPayload.self, from: rawData, eventType: envelope.type) {
                attachArtifact(payload)
            }

        case "session_started":
            if let payload = decodePayload(SessionStartedPayload.self, from: rawData, eventType: envelope.type) {
                currentSessionId = payload.sessionId
                messages = []
                seenMessageIds = []
                pendingArtifacts = [:]
                isAwaitingReply = false
            }

        case "error":
            if let payload = decodePayload(ErrorPayload.self, from: rawData, eventType: envelope.type) {
                lastErrorMessage = payload.message
                isAwaitingReply = false
            }

        default:
            print("[GwenViewModel] Unknown event type: \(envelope.type)")
        }
    }

    private func decodePayload<T: Decodable>(_ type: T.Type, from rawData: Data, eventType: String) -> T? {
        do {
            return try JSONDecoder().decode(GwenPayloadWrapper<T>.self, from: rawData).payload
        } catch {
            lastErrorMessage = "Couldn't parse '\(eventType)' event: \(error.localizedDescription)"
            print("[GwenViewModel] decode failed for \(eventType): \(error)")
            return nil
        }
    }

    private func appendIfNew(_ payload: ChatMessagePayload) {
        guard !seenMessageIds.contains(payload.id) else { return }
        seenMessageIds.insert(payload.id)

        var message = ChatMessage(
            id: payload.id,
            text: payload.displayText,
            isUser: payload.role == "user",
            timestamp: GwenDateParsing.parse(payload.timestamp)
        )

        if let artifact = pendingArtifacts.removeValue(forKey: payload.id) {
            message.artifact = artifact
        }

        withAnimation(.easeOut(duration: 0.25)) {
            messages.append(message)
        }

        if payload.role == "assistant" {
            isAwaitingReply = false
        }
    }

    private func attachArtifact(_ payload: FileReadyPayload) {
        let artifact = ChatArtifact(filePath: payload.filePath, fileType: payload.fileType)
        guard let index = messages.firstIndex(where: { $0.id == payload.messageId }) else {
            pendingArtifacts[payload.messageId] = artifact
            return
        }
        messages[index].artifact = artifact
    }

    func sendMessage() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        wsClient.send(InboundEventBuilder.sendText(text))
        prompt = ""
        isAwaitingReply = true
    }

    func setModelTier(_ tier: GwenMode) {
        selectedMode = tier
        wsClient.send(InboundEventBuilder.setModelTier(tier))
    }

    func toggleInputMode() {
        let newMode: InputMode = (inputMode == .voice) ? .text : .voice
        inputMode = newMode
        wsClient.send(InboundEventBuilder.setInputMode(newMode))
    }

    func uploadFile(at url: URL) {
        Task {
            do {
                let response = try await apiClient.uploadFile(fileURL: url)
                wsClient.send(InboundEventBuilder.sendText("[Uploaded file: \(response.filePath)]"))
                isAwaitingReply = true
            } catch {
                lastErrorMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
    }

    func refreshSessionList() {
        Task {
            do {
                sessions = try await apiClient.listSessions()
            } catch {
                lastErrorMessage = "Couldn't load sessions: \(error.localizedDescription)"
            }
        }
    }

    func openSession(_ session: SessionSummary) {
        Task {
            do {
                let detail = try await apiClient.loadSession(id: session.sessionId)
                currentSessionId = session.sessionId
                seenMessageIds = []
                pendingArtifacts = [:]
                isAwaitingReply = false

                var loadedMessages = detail.messages.map { payload in
                    ChatMessage(
                        id: payload.id,
                        text: payload.displayText,
                        isUser: payload.role == "user",
                        timestamp: GwenDateParsing.parse(payload.timestamp)
                    )
                }
                for payload in detail.messages {
                    seenMessageIds.insert(payload.id)
                }
                for artifact in detail.artifacts {
                    guard let filePath = artifact.filePath, let messageId = artifact.messageId else { continue }
                    if let index = loadedMessages.firstIndex(where: { $0.id == messageId }) {
                        loadedMessages[index].artifact = ChatArtifact(filePath: filePath, fileType: artifact.kind)
                    }
                }
                messages = loadedMessages
            } catch {
                lastErrorMessage = "Couldn't open session: \(error.localizedDescription)"
            }
        }
    }

    func startNewSession() {
        Task {
            do {
                _ = try await apiClient.startNewSession()
            } catch {
                lastErrorMessage = "Couldn't start new session: \(error.localizedDescription)"
            }
        }
    }
}
