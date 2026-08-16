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

    var backendLauncher: BackendLauncher

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
                    title: "Starting Gwen…",
                    detail: "Loading models -- this can take a while on first run.",
                    showSpinner: true
                )
            }
        }
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
            HStack(spacing: 0) {
                VStack {
                    GwenAvatarView(state: viewModel.currentState)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: geo.size.width * 0.65, height: geo.size.height * 0.85)

                GlowingDivider()

                VStack {
                    ChatPanel(viewModel: viewModel)
                        .frame(maxWidth: .infinity)
                    Spacer()
                    PromptBar(viewModel: viewModel, onUpload: { showFileImporter = true })
                        .padding()
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}

struct BackendStatusOverlay: View {
    let title: String
    let detail: String
    let showSpinner: Bool

    var body: some View {
        VStack(spacing: 16) {
            if showSpinner {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(Color(hex: "FF9F4D"))
            }

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(32)
    }
}

#Preview {
    ContentView(backendLauncher: BackendLauncher())
}
