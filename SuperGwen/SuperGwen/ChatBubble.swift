//
//  ChatBubble.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import SwiftUI
internal import Combine

struct ChatBubble: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme

    private var palette: GwenPalette {
        GwenPalette(colorScheme: colorScheme)
    }

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 80) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundStyle(message.isUser ? palette.userBubbleText : palette.assistantBubbleText)
                    .lineSpacing(3)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(bubbleBackground)

                if let artifact = message.artifact {
                    ArtifactPreview(artifact: artifact)
                }

                Text(message.timestamp.chatTimestampLabel)
                    .font(.caption)
                    .foregroundStyle(palette.tertiaryText)
            }
            .frame(maxWidth: 360, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser { Spacer(minLength: 80) }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity
        ))
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.isUser {
            RoundedRectangle(cornerRadius: 18)
                .fill(palette.userBubble)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(palette.hairline, lineWidth: 1)
                )
                .shadow(color: palette.shadow, radius: 14, y: 8)
        } else {
            RoundedRectangle(cornerRadius: 18)
                .fill(Gwen.bubbleGradient)
                .shadow(color: Gwen.glow, radius: 14, y: 8)
        }
    }
}

struct ArtifactPreview: View {
    let artifact: ChatArtifact
    @Environment(\.colorScheme) private var colorScheme

    private var palette: GwenPalette {
        GwenPalette(colorScheme: colorScheme)
    }

    var body: some View {
        Group {
            switch artifact.fileType {
            case "image":
                if let nsImage = NSImage(contentsOfFile: artifact.filePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(palette.hairline, lineWidth: 1)
                        )
                } else {
                    fileChip(systemImage: "photo")
                }
            case "pdf":
                fileChip(systemImage: "doc.richtext")
            case "docx":
                fileChip(systemImage: "doc.text")
            default:
                fileChip(systemImage: "doc")
            }
        }
    }

    private func fileChip(systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text((artifact.filePath as NSString).lastPathComponent)
                .lineLimit(1)
        }
        .font(.footnote)
        .foregroundStyle(palette.text)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(palette.elevatedPanel))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(palette.hairline, lineWidth: 1)
        )
    }
}

struct TypingIndicatorBubble: View {
    @State private var phase = 0
    @Environment(\.colorScheme) private var colorScheme

    private let dotCount = 3
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()
    private var palette: GwenPalette { GwenPalette(colorScheme: colorScheme) }

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<dotCount, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(phase == i ? 0.95 : 0.55))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Gwen.bubbleGradient)
                    .shadow(color: Gwen.glow, radius: 14, y: 8)
            )
            .onReceive(timer) { _ in
                phase = (phase + 1) % dotCount
            }

            Spacer(minLength: 80)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
