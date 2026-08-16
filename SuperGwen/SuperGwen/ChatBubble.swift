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

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(bubbleFill)
                            .opacity(message.isUser ? 1.0 : 0.85)
                    )

                if let artifact = message.artifact {
                    ArtifactPreview(artifact: artifact)
                }
                Text(message.timestamp.chatTimestampLabel)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            if !message.isUser { Spacer(minLength: 40) }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity
        ))
    }

    var bubbleFill: AnyShapeStyle {
        if message.isUser {
            AnyShapeStyle(Color(white: 0.15))
        } else {
            AnyShapeStyle(Gwen.gradient)
        }
    }
}

struct ArtifactPreview: View {
    let artifact: ChatArtifact

    var body: some View {
        Group {
            switch artifact.fileType {
            case "image":
                if let nsImage = NSImage(contentsOfFile: artifact.filePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text((artifact.filePath as NSString).lastPathComponent)
                .lineLimit(1)
        }
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.8))
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.12)))
    }
}

struct TypingIndicatorBubble: View {
    @State private var phase = 0

    private let dotCount = 3
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<dotCount, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(phase == i ? 0.9 : 0.35))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Gwen.gradient)
                    .opacity(0.85)
            )
            .onReceive(timer) { _ in
                phase = (phase + 1) % dotCount
            }

            Spacer(minLength: 40)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
