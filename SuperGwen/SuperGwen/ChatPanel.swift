//
//  ChatPanel.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import SwiftUI

enum ChatDisplayMode {
    case activeChat
    case sessionList
}

struct ChatPanel: View {
    var viewModel: GwenViewModel

    @State private var displayMode: ChatDisplayMode = .activeChat

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if displayMode == .sessionList {
                    Text("Sessions")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Menu {
                    Button {
                        viewModel.startNewSession()
                        displayMode = .activeChat
                    } label: {
                        Label("New session", systemImage: "plus.bubble")
                    }

                    Button {
                        viewModel.refreshSessionList()
                        displayMode = .sessionList
                    } label: {
                        Label("Session history", systemImage: "clock.arrow.circlepath")
                    }

                    if displayMode == .sessionList {
                        Divider()
                        Button {
                            displayMode = .activeChat
                        } label: {
                            Label("Back to chat", systemImage: "chevron.left")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            switch displayMode {
            case .activeChat:
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isAwaitingReply {
                                TypingIndicatorBubble()
                                    .id("typing-indicator")
                            }
                        }
                        .padding()
                        .animation(.easeOut(duration: 0.25), value: viewModel.messages)
                        .animation(.easeOut(duration: 0.2), value: viewModel.isAwaitingReply)
                    }
                    // Auto-scroll to the newest message, or the typing
                    // indicator when it appears, so the chat always feels live.
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.isAwaitingReply) { _, isAwaiting in
                        if isAwaiting {
                            withAnimation { proxy.scrollTo("typing-indicator", anchor: .bottom) }
                        }
                    }
                }

            case .sessionList:
                SessionListPanel(viewModel: viewModel) { session in
                    viewModel.openSession(session)
                    displayMode = .activeChat
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if viewModel.isAwaitingReply {
            withAnimation { proxy.scrollTo("typing-indicator", anchor: .bottom) }
        } else if let lastId = viewModel.messages.last?.id {
            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        }
    }
}

struct SessionListPanel: View {
    var viewModel: GwenViewModel
    var onSelect: (SessionSummary) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.sessions.isEmpty {
                    Text("No past sessions yet")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding()
                }

                ForEach(viewModel.sessions) { session in
                    Button {
                        onSelect(session)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title ?? "Session \(session.sessionId)")
                                .foregroundStyle(.white)
                                .font(.footnote)
                            Text(session.lastActiveAt)
                                .foregroundStyle(.white.opacity(0.4))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(Color.white.opacity(0.1))
                }
            }
            .padding(.horizontal)
        }
    }
}
