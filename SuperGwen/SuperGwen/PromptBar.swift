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
    @Environment(\.colorScheme) private var colorScheme

    private var isEnabled: Bool { viewModel.inputMode == .text }
    private var palette: GwenPalette { GwenPalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                Button {
                    if viewModel.inputMode != .voice {
                        viewModel.toggleInputMode()
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 62)
                        .background(Circle().fill(Gwen.gradient))
                        .shadow(color: Gwen.glow, radius: 18, y: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                                .scaleEffect(viewModel.currentState == .listening ? 1.22 : 1)
                                .opacity(viewModel.currentState == .listening ? 0.3 : 0)
                                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: viewModel.currentState == .listening)
                        )
                }
                .buttonStyle(.plain)
                .help("Switch to voice mode")

                InlineModelTierPicker(
                    selection: Binding(
                        get: { viewModel.selectedMode },
                        set: { viewModel.setModelTier($0) }
                    ),
                    palette: palette
                )

                ZStack(alignment: .leading) {
                    if viewModel.prompt.isEmpty {
                        Text(isEnabled ? "Speak or type your message..." : "Listening -- say \"Gwen\" to start")
                            .foregroundStyle(palette.tertiaryText)
                    }

                    TextField("", text: Binding(
                        get: { viewModel.prompt },
                        set: { viewModel.prompt = $0 }
                    ), axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .foregroundStyle(palette.text)
                    .lineLimit(1...5)
                    .disabled(!isEnabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onUpload) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isEnabled ? palette.secondaryText : palette.tertiaryText.opacity(0.55))
                .disabled(!isEnabled)
                .help("Attach a file")

                VoiceTextToggle(viewModel: viewModel)

                Button(action: { viewModel.sendMessage() }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(isEnabled ? AnyShapeStyle(Gwen.gradient) : AnyShapeStyle(palette.tertiaryText.opacity(0.45))))
                        .shadow(color: isEnabled ? Gwen.glow : .clear, radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Send message")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(palette.elevatedPanel)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Gwen.gradient, lineWidth: isEnabled ? 1.5 : 1)
                            .opacity(isEnabled ? 0.95 : 0.35)
                    )
                    .shadow(color: isEnabled ? Gwen.glow.opacity(0.45) : palette.shadow, radius: isEnabled ? 18 : 12, y: 8)
            )

            Text("Press Command-K to switch between voice and text")
                .font(.caption)
                .foregroundStyle(palette.tertiaryText)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.inputMode)
    }
}

struct InlineModelTierPicker: View {
    @Binding var selection: GwenMode
    let palette: GwenPalette

    var body: some View {
        Menu {
            Picker("Model", selection: $selection) {
                ForEach(GwenMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                Text(selection.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(palette.secondaryText)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                Capsule()
                    .stroke(palette.hairline, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Model tier")
    }
}

struct VoiceTextToggle: View {
    var viewModel: GwenViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: GwenPalette { GwenPalette(colorScheme: colorScheme) }

    var body: some View {
        Button {
            viewModel.toggleInputMode()
        } label: {
            Image(systemName: viewModel.inputMode == .voice ? "keyboard" : "mic.fill")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("k", modifiers: .command)
        .foregroundStyle(palette.secondaryText)
        .help(viewModel.inputMode == .voice ? "Switch to text mode" : "Switch to voice mode")
    }
}

struct ListeningMicIndicator: View {
    let isListening: Bool

    @State private var pulse = false

    var body: some View {
        Image(systemName: "waveform")
            .font(.footnote)
            .foregroundStyle(isListening ? AnyShapeStyle(Gwen.gradient) : AnyShapeStyle(.secondary.opacity(0.55)))
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
