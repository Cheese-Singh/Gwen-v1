//
//  PromptBar.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import SwiftUI

struct PromptBar: View {
    var viewModel: GwenViewModel
    var onUpload: () -> Void

    private var isEnabled: Bool { viewModel.inputMode == .text }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .leading) {
                if viewModel.prompt.isEmpty {
                    Text(isEnabled ? "What's on your mind" : "Listening — say \"Gwen\" to start")
                        .foregroundStyle(.white.opacity(0.4))
                }
                TextField("", text: Binding(
                    get: { viewModel.prompt },
                    set: { viewModel.prompt = $0 }
                ), axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .lineLimit(1...6)
                    .disabled(!isEnabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button(action: onUpload) {
                    Image(systemName: "paperclip")
                        .foregroundStyle(isEnabled ? AnyShapeStyle(Gwen.gradient) : AnyShapeStyle(.white.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)

                ModePicker(mode: Binding(
                    get: { viewModel.selectedMode },
                    set: { viewModel.setModelTier($0) }
                ))
                .opacity(isEnabled ? 1.0 : 0.5)

                if viewModel.inputMode == .voice {
                    ListeningMicIndicator(isListening: viewModel.currentState == .listening)
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                VoiceTextToggle(viewModel: viewModel)

                Button(action: { viewModel.sendMessage() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(isEnabled ? AnyShapeStyle(Gwen.gradient) : AnyShapeStyle(.white.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.inputMode)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: isEnabled ? 0.08 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isEnabled ? AnyShapeStyle(Gwen.gradient) : AnyShapeStyle(Color.white.opacity(0.25)),
                    lineWidth: isEnabled ? 2 : 1
                )
        )
        .shadow(color: isEnabled ? Gwen.glow : .clear, radius: isEnabled ? 6 : 0)
        .animation(.easeInOut(duration: 0.25), value: isEnabled)
    }
}

struct VoiceTextToggle: View {
    var viewModel: GwenViewModel

    var body: some View {
        Button {
            viewModel.toggleInputMode()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: viewModel.inputMode == .voice ? "mic.fill" : "keyboard")
                    .font(.caption)
            }
            .foregroundStyle(Gwen.gradient)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().stroke(Gwen.gradient, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(viewModel.inputMode == .voice ? "Switch to text mode" : "Switch to voice mode")
    }
}

struct ListeningMicIndicator: View {
    let isListening: Bool

    @State private var pulse = false

    var body: some View {
        Image(systemName: "waveform")
            .font(.footnote)
            .foregroundStyle(isListening ? AnyShapeStyle(Gwen.gradient) : AnyShapeStyle(.white.opacity(0.35)))
            .scaleEffect(isListening && pulse ? 1.15 : 1.0)
            .onAppear { syncPulse() }
            .onChange(of: isListening) { _, _ in syncPulse() }
    }

    private func syncPulse() {
        if isListening {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                pulse = false
            }
        }
    }
}
