import SwiftUI

/// Equivalente iOS de com.poly.music.MainActivity:
///   enableEdgeToEdge()  → iOS ya es edge-to-edge por defecto
///   PolyTheme { LibraryScreen() } → .preferredColorScheme + fondo PolyTheme
@main
struct PolyMusicApp: App {
    // Estado global compartido (equivalente a los `remember { }` de LibraryScreen
    // pero elevado a app scope para que sobreviva a la navegación de tabs)
    @StateObject private var player = AudioPlayerManager()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(player)
                .tint(PolyTheme.primary)
                .preferredColorScheme(PolyTheme.preferredColorScheme)
                .background(PolyTheme.background.ignoresSafeArea())
        }
    }
}
