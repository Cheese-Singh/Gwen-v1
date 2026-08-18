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
        Color(hex: "FF7FB0"),
        Color(hex: "D944FF")
    ]
    static let gradient = LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    static let verticalGradient = LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    static let glow = Color(hex: "FF7FB0").opacity(0.38)
    
    static let bubbleGradient = LinearGradient(
        colors: [Color(hex: "F2B65C"), Color(hex: "F2739E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum GwenAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

struct GwenPalette {
    let background: Color
    let panel: Color
    let elevatedPanel: Color
    let text: Color
    let secondaryText: Color
    let tertiaryText: Color
    let hairline: Color
    let userBubble: Color
    let userBubbleText: Color
    let assistantBubbleText: Color
    let shadow: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            background = Color(hex: "10111A")
            panel = Color(hex: "171823").opacity(0.92)
            elevatedPanel = Color(hex: "202130").opacity(0.94)
            text = Color(hex: "F8F7FF")
            secondaryText = Color(hex: "C7C5DA")
            tertiaryText = Color(hex: "8D8AA6")
            hairline = Color.white.opacity(0.11)
            userBubble = Color(hex: "242638")
            userBubbleText = Color(hex: "F8F7FF")
            assistantBubbleText = Color(hex: "1A1220")
            shadow = Color.black.opacity(0.34)
        } else {
            background = Color(hex: "F7F5FB")
            panel = Color.white.opacity(0.72)
            elevatedPanel = Color.white.opacity(0.9)
            text = Color(hex: "14142B")
            secondaryText = Color(hex: "686982")
            tertiaryText = Color(hex: "9698AD")
            hairline = Color(hex: "DDDCEA").opacity(0.72)
            userBubble = Color(hex: "F3F1F8")
            userBubbleText = Color(hex: "14142B")
            assistantBubbleText = Color(hex: "1A1220")
            shadow = Color(hex: "BDB8D0").opacity(0.24)
        }
    }

    var assistantBubble: Color { .clear }
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
