import SwiftUI

// =====================================================================
// FullPlayerView — equivalente del composable FullPlayerScreen
// (título, arte, slider de progreso, controles anterior/play/siguiente)
// =====================================================================
struct FullPlayerView: View {
    @EnvironmentObject private var player: AudioPlayerManager
    var onClose: () -> Void

    @State private var showEqualizer = false
    /// Evita que el slider "rebote" hacia la posición observada mientras el usuario arrastra
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            // TopAppBar: "Reproduciendo ahora" + back + ecualizador
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                Spacer()
                Text("Reproduciendo ahora")
                    .font(.headline)
                Spacer()
                Button {
                    showEqualizer = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
            .padding(.horizontal)

            Spacer()

            // Card 280x280 con arte (RoundedCornerShape(16.dp) + elevation 8.dp)
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(PolyTheme.surface)
                    .frame(width: 280, height: 280)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                if let art = player.currentAlbumArt {
                    Image(uiImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 280, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .transition(.opacity)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundStyle(.secondary)
                }
            }

            // Título + artista
            VStack(spacing: 4) {
                Text(player.currentSongTitle.isEmpty ? "Sin reproducción" : player.currentSongTitle)
                    .font(.title3)
                    .lineLimit(1)
                Text(player.currentArtistName.isEmpty ? "Desconocido" : player.currentArtistName)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal)

            // Slider de progreso (MediaController.seekTo)
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { isScrubbing ? scrubValue : player.currentPosition },
                        set: { scrubValue = $0 }
                    ),
                    in: 0...max(player.duration, 1),
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing {
                            player.seek(to: scrubValue)
                        }
                    }
                )
                .accentColor(PolyTheme.primary)
                HStack {
                    Text(formatTime(Int(player.currentPosition)))
                    Spacer()
                    Text(formatTime(Int(player.duration)))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            // Controles: anterior / play-pause (72dp) / siguiente
            HStack(spacing: 40) {
                Button {
                    player.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 30))
                }
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 40))
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(PolyTheme.primary))
                        .foregroundStyle(.white)
                }
                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 30))
                }
            }
            .foregroundStyle(.primary)

            Spacer()
        }
        .background(PolyTheme.background)
        .sheet(isPresented: $showEqualizer) {
            EqualizerView()
                .presentationDetents([.medium, .large])
        }
    }

    @State private var scrubValue: Double = 0

    /// formatTime(ms) → iOS trabaja en segundos
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
