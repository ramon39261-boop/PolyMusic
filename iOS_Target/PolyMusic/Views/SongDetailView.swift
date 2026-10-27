import SwiftUI

// =====================================================================
// SongDetailView — equivalente del composable SongDetailScreen
// =====================================================================
struct SongDetailView: View {
    @EnvironmentObject private var player: AudioPlayerManager

    let title: String
    let subtitle: String
    let songs: [Song]
    var onClose: () -> Void
    var onPlayAll: (Song) -> Void

    @State private var showFullPlayer = false

    var body: some View {
        VStack(spacing: 0) {
            // TopAppBar
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                Text(title)
                    .font(.title3.bold())
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Subtítulo: ruta / nº de canciones / artista
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(16)

            SongListView(songs: songs, onSongClick: onPlayAll)

            // MiniPlayer fijo
            if !player.currentSongTitle.isEmpty {
                MiniPlayerView(onOpen: { showFullPlayer = true })
            }
        }
        .background(PolyTheme.background)
        .fullScreenCover(isPresented: $showFullPlayer) {
            FullPlayerView(onClose: { showFullPlayer = false })
        }
    }
}
