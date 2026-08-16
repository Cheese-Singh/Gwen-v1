//
//  GwenTheme.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import SwiftUI

enum Gwen {
    static let colors: [Color] = [
            Color(hex: "FFD966"),
            Color(hex: "FF9F4D"),
            Color(hex: "FF7FB0")
        ]
        static let gradient = LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
        static let glow = Color(hex: "FF9F4D").opacity(0.5)
}

extension View {
    func neonGradientBorder(cornerRadius: CGFloat = 12) -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(white: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Gwen.gradient, lineWidth: 2)
            )
            .shadow(color: Gwen.glow, radius: 6)
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue >> 16) & 0xFF) / 255
        let g = Double((rgbValue >> 8) & 0xFF) / 255
        let b = Double(rgbValue & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}
