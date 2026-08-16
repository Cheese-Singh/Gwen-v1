//
//  GwenWebSocket.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 14/08/2026.
//

import Foundation

final class GwenWebSocketClient: NSObject {

    var onEvent: ((GwenEventEnvelope, Data) -> Void)?
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?

    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private let url: URL

    private var shouldReconnect = false
    private var reconnectAttempt = 0
    private let maxBackoffSeconds: TimeInterval = 30
    private var reconnectWorkItem: DispatchWorkItem?
    private var hasSignaledConnect = false

    init(url: URL) {
        self.url = url
        self.session = URLSession(configuration: .default)
        super.init()
    }

    func connect() {
        reconnectWorkItem?.cancel()
        shouldReconnect = true
        hasSignaledConnect = false
        openSocket()
    }

    private func openSocket() {
        task?.cancel(with: .goingAway, reason: nil)
        let newTask = session.webSocketTask(with: url)
        task = newTask
        newTask.resume()
        listen()
        confirmHandshake()
    }

    private func confirmHandshake() {
        guard let task else { return }
        task.sendPing { [weak self] error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error {
                    print("[GwenWebSocketClient] handshake ping failed: \(error)")
                    self.handleFailure()
                } else {
                    self.reconnectAttempt = 0
                    if !self.hasSignaledConnect {
                        self.hasSignaledConnect = true
                        self.onConnect?()
                    }
                }
            }
        }
    }

    func disconnect() {
        shouldReconnect = false
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        reconnectAttempt = 0
        hasSignaledConnect = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    func send<T: Encodable>(_ event: T) {
        guard let task else { return }
        do {
            let data = try JSONEncoder().encode(event)
            guard let text = String(data: data, encoding: .utf8) else { return }
            task.send(.string(text)) { [weak self] error in
                if let error {
                    print("[GwenWebSocketClient] send failed: \(error)")
                    DispatchQueue.main.async {
                        self?.handleFailure()
                    }
                }
            }
        } catch {
            print("[GwenWebSocketClient] encode failed: \(error)")
        }
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                print("[GwenWebSocketClient] receive failed: \(error)")
                DispatchQueue.main.async {
                    self.handleFailure()
                }
                return

            case .success(let message):
                switch message {
                case .string(let text):
                    self.decodeAndDispatch(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.decodeAndDispatch(text)
                    }
                @unknown default:
                    break
                }
                self.listen()
            }
        }
    }

    private func handleFailure() {
        task = nil

        if hasSignaledConnect {
            hasSignaledConnect = false
            onDisconnect?()
        }

        guard shouldReconnect else { return }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectWorkItem?.cancel()

        let delay = min(pow(2.0, Double(reconnectAttempt)), maxBackoffSeconds)
        reconnectAttempt += 1

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.shouldReconnect else { return }
            self.openSocket()
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func decodeAndDispatch(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            let envelope = try JSONDecoder().decode(GwenEventEnvelope.self, from: data)
            DispatchQueue.main.async { [weak self] in
                self?.onEvent?(envelope, data)
            }
        } catch {
            print("[GwenWebSocketClient] decode failed: \(error) -- raw: \(text)")
        }
    }
}
