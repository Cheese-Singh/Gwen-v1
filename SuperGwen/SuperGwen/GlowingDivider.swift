//
//  GlowingDivider.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import SwiftUI

struct GlowingDivider: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "FFD966"), // yellow
                Color(hex: "FF9F4D"), // orange
                Color(hex: "FF7FB0")  // pink
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 2)
        .padding(.vertical, 40)
        .shadow(color: .purple.opacity(0.6), radius: 2)
    }
}
