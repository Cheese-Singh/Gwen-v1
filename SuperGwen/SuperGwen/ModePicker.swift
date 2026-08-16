//
//  ModelPicker.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import SwiftUI

struct ModePicker: View {
    @Binding var mode: GwenMode

    var body: some View {
        Menu {
            ForEach(GwenMode.allCases) { m in
                Button(m.rawValue) { mode = m }
            }
        } label: {
            HStack(spacing: 4) {
                Text(mode.rawValue)
                    .foregroundStyle(Gwen.gradient)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(Color(hex: "FF9F4D"))
            }
            .font(.footnote)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
