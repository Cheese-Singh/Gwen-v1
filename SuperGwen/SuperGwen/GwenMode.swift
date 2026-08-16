//
//  ModelPicker.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import SwiftUI

enum GwenMode: String, Codable, CaseIterable, Identifiable {
    case veryLight = "Very Light"
    case light = "Light"
    case regular = "Regular"
    case max = "MAX"

    var id: String { rawValue }
}
