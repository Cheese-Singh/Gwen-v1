//
//  ChatPanel.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import SwiftUI

struct ChatPanel: View {
    var viewModel: GwenViewModel
    var onUpload: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var palette: GwenPalette {
        GwenPalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.tertiaryText)
                .padding(.top, 34)
                .padding(.bottom, 18)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        if viewModel.messages.isEmpty && !viewModel.isAwaitingReply {
                            EmptyChatHint(palette: palette)
                                .frame(maxWidth: .infinity, minHeight: 260)
                        }

                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isAwaitingReply {
                            TypingIndicatorBubble()
                                .id("typing-indicator")
                        }
                    }
                    .padding(.horizontal, 38)
                    .padding(.vertical, 8)
                    .animation(.easeOut(duration: 0.25), value: viewModel.messages)
                    .animation(.easeOut(duration: 0.2), value: viewModel.isAwaitingReply)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.isAwaitingReply) { _, isAwaiting in
                    if isAwaiting {
                        withAnimation { proxy.scrollTo("typing-indicator", anchor: .bottom) }
                    }
                }
            }

            PromptBar(viewModel: viewModel, onUpload: onUpload)
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
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

struct EmptyChatHint: View {
    let palette: GwenPalette

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Gwen.gradient)
            Text("Ask Gwen anything")
                .font(.headline)
                .foregroundStyle(palette.text)
            Text("Your conversation will appear here.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
    }
}
