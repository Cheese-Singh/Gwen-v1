//
//  GwenState.swift
//  SuperGwen
//
//  Created by Ekamveer Singh on 15/07/2026.
//

import SwiftUI

enum GwenState: String, Codable, CaseIterable, Identifiable {
    case idle
    case thinking
    case listening
    case speaking

    var id: String { rawValue }

    var image: Image {
        Image(rawValue)
    }
}
