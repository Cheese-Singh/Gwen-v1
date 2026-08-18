//
//  ContentView.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = GwenViewModel()
    @State private var showFileImporter = false
    @State private var showSessions = false
    @AppStorage("gwenAppearance") private var appearanceRawValue = GwenAppearance.system.rawValue
    @Environment(\.colorScheme) private var colorScheme

    var backendLauncher: BackendLauncher

    private var appearance: GwenAppearance {
        get { GwenAppearance(rawValue: appearanceRawValue) ?? .system }
        nonmutating set { appearanceRawValue = newValue.rawValue }
    }

    private var palette: GwenPalette {
        GwenPalette(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            switch backendLauncher.status {
            case .ready:
                mainContent

            case .failed(let reason):
                BackendStatusOverlay(
                    title: "Backend failed to start",
                    detail: reason,
                    showSpinner: false
                )

            case .notStarted, .launching, .waitingForHealth:
                BackendStatusOverlay(
                    title: "Starting Gwen...",
                    detail: "Loading models -- this can take a while on first run.",
                    showSpinner: true
                )
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .onAppear {
            backendLauncher.launch()
        }
        .onChange(of: backendLauncher.status) { _, newStatus in
            if newStatus == .ready {
                viewModel.connect()
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .pdf, .plainText, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.uploadFile(at: url)
                }
            case .failure(let error):
                viewModel.lastErrorMessage = "File selection failed: \(error.localizedDescription)"
            }
        }
    }

    private var mainContent: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                VStack(spacing: 18) {
                    topBar

                    HStack(spacing: 0) {
                        assistantPanel
                            .frame(width: assistantPanelWidth(for: geo.size.width))

                        GlowingDivider()
                            .frame(width: 1)
                            .padding(.vertical, 8)

                        ChatPanel(viewModel: viewModel, onUpload: { showFileImporter = true })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 18)
                .blur(radius: showSessions ? 1.5 : 0)

                if showSessions {
                    Color.black.opacity(colorScheme == .dark ? 0.34 : 0.12)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) { showSessions = false } }

                    SessionDrawer(viewModel: viewModel, palette: palette) { session in
                        viewModel.openSession(session)
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) { showSessions = false }
                    } onNewSession: {
                        viewModel.startNewSession()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) { showSessions = false }
                    } onClose: {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) { showSessions = false }
                    }
                    .frame(width: min(330, max(280, geo.size.width * 0.28)))
                    .padding(.leading, 18)
                    .padding(.vertical, 18)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                viewModel.refreshSessionList()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) { showSessions.toggle() }
            } label: {
                Image(systemName: showSessions ? "xmark" : "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(palette.elevatedPanel, in: RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.text)
            .help(showSessions ? "Hide sessions" : "Show sessions")

            Text("SuperGwen")
                .font(.headline)
                .foregroundStyle(palette.text)

            Spacer()

            AppearanceQuickToggle(appearance: Binding(
                get: { appearance },
                set: { appearance = $0 }
            ), palette: palette)

            SettingsMenu(
                appearance: Binding(
                    get: { appearance },
                    set: { appearance = $0 }
                ),
                viewModel: viewModel,
                palette: palette
            )

            Divider()
                .frame(height: 22)

            Toggle(isOn: Binding(
                get: { viewModel.inputMode == .voice },
                set: { shouldUseVoice in
                    let nextMode: InputMode = shouldUseVoice ? .voice : .text
                    if viewModel.inputMode != nextMode {
                        viewModel.toggleInputMode()
                    }
                }
            )) {
                Text("Voice Mode")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
            .toggleStyle(.switch)
            .tint(Color(hex: "FF7FB0"))
            .fixedSize()
        }
    }

    private var assistantPanel: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            GwenAvatarView(state: viewModel.currentState)
                .frame(maxWidth: 260, maxHeight: 260)
                .shadow(color: Gwen.glow, radius: 28)

            VStack(spacing: 6) {
                Text("Gwen")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(palette.text)
                Text("Voice-first AI assistant")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }

            ListeningStatusPill(state: viewModel.currentState, palette: palette)

            InputModeCards(viewModel: viewModel, palette: palette)

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                Button {
                    // Settings entry point lives in the top bar menu; this
                    // mirrors the quick-access affordance from the target design.
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.refreshSessionList()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) { showSessions = true }
                } label: {
                    Label("Memory", systemImage: "square.stack.3d.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .font(.subheadline)
            .foregroundStyle(palette.secondaryText)
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }

    private func assistantPanelWidth(for totalWidth: CGFloat) -> CGFloat {
        min(360, max(280, totalWidth * 0.3))
    }
}

/// Small sun/moon quick toggle beside the settings gear, cycling
/// system -> light -> dark -> system.
struct AppearanceQuickToggle: View {
    @Binding var appearance: GwenAppearance
    let palette: GwenPalette

    var body: some View {
        Button {
            appearance = next(after: appearance)
        } label: {
            Image(systemName: appearance.systemImage)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 38, height: 38)
                .background(palette.elevatedPanel, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.text)
        .help("Appearance: \(appearance.rawValue)")
    }

    private func next(after current: GwenAppearance) -> GwenAppearance {
        switch current {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }
}

struct SettingsMenu: View {
    @Binding var appearance: GwenAppearance
    var viewModel: GwenViewModel
    let palette: GwenPalette

    var body: some View {
        Menu {
            Picker("Appearance", selection: $appearance) {
                ForEach(GwenAppearance.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }

            Divider()

            Picker("Model", selection: Binding(
                get: { viewModel.selectedMode },
                set: { viewModel.setModelTier($0) }
            )) {
                ForEach(GwenMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 38, height: 38)
                .background(palette.elevatedPanel, in: RoundedRectangle(cornerRadius: 11))
        }
        .menuStyle(.borderlessButton)
        .foregroundStyle(palette.text)
        .help("Settings")
    }
}

struct InputModeCards: View {
    var viewModel: GwenViewModel
    let palette: GwenPalette

    var body: some View {
        HStack(spacing: 8) {
            modeButton(title: "Voice", systemImage: "mic.fill", mode: .voice)
            modeButton(title: "Text", systemImage: "keyboard", mode: .text)
            modeButton(title: "Hybrid", systemImage: "slider.horizontal.3", mode: .text)
        }
        .padding(8)
        .background(palette.elevatedPanel, in: RoundedRectangle(cornerRadius: 18))
    }

    private func modeButton(title: String, systemImage: String, mode: InputMode) -> some View {
        Button {
            if viewModel.inputMode != mode {
                viewModel.toggleInputMode()
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(viewModel.inputMode == mode ? AnyShapeStyle(Gwen.gradient) : AnyShapeStyle(palette.secondaryText))
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(viewModel.inputMode == mode ? palette.panel : .clear)
                    .shadow(color: viewModel.inputMode == mode ? Gwen.glow : .clear, radius: 12)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ListeningStatusPill: View {
    let state: GwenState
    let palette: GwenPalette

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state == .listening ? "waveform" : "sparkles")
                .foregroundStyle(Gwen.gradient)
            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.text)
            Image(systemName: "waveform.path")
                .foregroundStyle(Gwen.gradient)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(palette.elevatedPanel, in: Capsule())
    }

    private var statusText: String {
        switch state {
        case .idle:
            "Ready"
        case .thinking:
            "Thinking..."
        case .listening:
            "Listening..."
        case .speaking:
            "Speaking..."
        }
    }
}

private enum SessionGroup: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case earlier = "Earlier"
}

private struct GroupedSessions: Identifiable {
    let id: SessionGroup
    let sessions: [SessionSummary]
}

struct SessionDrawer: View {
    var viewModel: GwenViewModel
    let palette: GwenPalette
    var onSelect: (SessionSummary) -> Void
    var onNewSession: () -> Void
    var onClose: () -> Void

    @State private var searchText = ""

    private var filteredSessions: [SessionSummary] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.sessions }
        return viewModel.sessions.filter { session in
            let title = session.title ?? "Session \(session.sessionId)"
            return title.localizedCaseInsensitiveContains(trimmed)
                || session.lastActiveAt.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var groupedSessions: [GroupedSessions] {
        let calendar = Calendar.current
        let now = Date()

        var buckets: [SessionGroup: [SessionSummary]] = [:]

        for session in filteredSessions {
            let date = GwenDateParsing.parse(session.lastActiveAt)
            let group: SessionGroup
            if calendar.isDateInToday(date) {
                group = .today
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), date >= weekAgo {
                group = .thisWeek
            } else if let monthAgo = calendar.date(byAdding: .day, value: -30, to: now), date >= monthAgo {
                group = .thisMonth
            } else {
                group = .earlier
            }
            buckets[group, default: []].append(session)
        }

        return SessionGroup.allCases.compactMap { group in
            guard let sessions = buckets[group], !sessions.isEmpty else { return nil }
            return GroupedSessions(id: group, sessions: sessions)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(palette.elevatedPanel, in: RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.text)

                Spacer()

                Button(action: onNewSession) {
                    Label("New Chat", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .stroke(Gwen.gradient, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(Gwen.gradient)
            }

            Text("Sessions")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.text)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.tertiaryText)
                TextField("Search chats", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(palette.text)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(palette.elevatedPanel, in: Capsule())

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if groupedSessions.isEmpty {
                        Text(viewModel.sessions.isEmpty ? "No past sessions yet" : "No matching sessions")
                            .font(.footnote)
                            .foregroundStyle(palette.tertiaryText)
                            .padding(.top, 12)
                    }

                    ForEach(groupedSessions) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.id.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.tertiaryText)
                                .padding(.leading, 2)

                            ForEach(group.sessions) { session in
                                sessionRow(session)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(palette.panel)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(palette.hairline, lineWidth: 1)
                )
                .shadow(color: palette.shadow, radius: 30, y: 14)
        )
    }

    private func sessionRow(_ session: SessionSummary) -> some View {
        Button {
            onSelect(session)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(session.title ?? "Session \(session.sessionId)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    Spacer()
                    Text(session.lastActiveAt)
                        .font(.caption2)
                        .foregroundStyle(palette.tertiaryText)
                        .lineLimit(1)
                }
                Text("Open conversation")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.elevatedPanel)
            )
        }
        .buttonStyle(.plain)
    }
}

struct BackendStatusOverlay: View {
    let title: String
    let detail: String
    let showSpinner: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var palette: GwenPalette {
        GwenPalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 16) {
            if showSpinner {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color(hex: "FF7FB0"))
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(Color(hex: "FF9F4D"))
            }

            Text(title)
                .font(.headline)
                .foregroundStyle(palette.text)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(32)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

#Preview {
    ContentView(backendLauncher: BackendLauncher())
}
