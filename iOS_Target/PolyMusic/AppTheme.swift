import SwiftUI

/// Equivalente iOS de com.poly.player.ui.theme (Theme.kt).
/// Mismos colores del darkColorScheme de PolyTheme:
///   primary #3B82F6, secondary #10B981, background #0F172A, surface #1E293B
enum PolyTheme {
    static let primary    = Color(red: 0x3B / 255, green: 0x82 / 255, blue: 0xF6 / 255)
    static let secondary  = Color(red: 0x10 / 255, green: 0xB9 / 255, blue: 0x81 / 255)
    static let background = Color(red: 0x0F / 255, green: 0x17 / 255, blue: 0x2A / 255)
    static let surface    = Color(red: 0x1E / 255, green: 0x29 / 255, blue: 0x3B / 255)  // PolyCard
    static let cardFocus  = Color(red: 0x33 / 255, green: 0x41 / 255, blue: 0x55 / 255) // PolyCardFocused

    /// Aplica el fondo global, igual que PolyTheme { } envolvía el setContent de MainActivity
    static var preferredColorScheme: ColorScheme { .dark }
}
