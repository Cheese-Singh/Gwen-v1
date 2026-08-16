//
//  GwenAnimation.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 16/07/2026.
//

import SwiftUI

struct GwenAvatarView: View {
    let state: GwenState

    var body: some View {
        state.image
            .resizable()
            .scaledToFit()
            .id(state)
            .transition(.opacity.animation(GwenAnimation.stateTransition))
            .animation(GwenAnimation.stateTransition, value: state)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var state: GwenState = .idle
        var body: some View {
            VStack {
                GwenAvatarView(state: state)
                    .frame(height: 300)
                Picker("State", selection: $state) {
                    Text("Idle").tag(GwenState.idle)
                    Text("Listening").tag(GwenState.listening)
                    Text("Thinking").tag(GwenState.thinking)
                    Text("Speaking").tag(GwenState.speaking)
                }
                .pickerStyle(.segmented)
                .padding()
            }
        }
    }
    return PreviewWrapper()
}
