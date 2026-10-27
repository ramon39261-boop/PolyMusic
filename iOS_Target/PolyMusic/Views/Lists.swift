import SwiftUI
import AVFoundation

// =====================================================================
// Listas de la biblioteca — equivalentes de SongList / FolderList /
// ArtistList / AlbumList de LibraryScreen.kt (LazyColumn → List)
// =====================================================================

struct SongListView: View {
    @EnvironmentObject private var player: AudioPlayerManager
    let songs: [Song]
    var onSongClick: (Song) -> Void

    var body: some View {
        if songs.isEmpty {
            emptyState("No se encontraron canciones")
        } else {
            List(songs) { song in
                Button { onSongClick(song) } label: {
                    SongRow(song: song, isCurrent: isCurrent(song))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
            .listStyle(.plain)
        }
    }

    /// La fila "current" se resalta igual que la UI Android marca
    /// la canción activa vía currentSongTitle del MediaController
    private func isCurrent(_ song: Song) -> Bool {
        !player.currentSongTitle.isEmpty && player.currentSongTitle == song.title
            && player.currentArtistName == song.artist
    }

    private func emptyState(_ message: String) -> some View {
        VStack { Spacer(); Text(message).foregroundStyle(.secondary); Spacer() }
    }
}

/// Fila de canción: encabezado + soporte + arte.
/// (Android tenía botón de borrar con AlertDialog; en iOS la biblioteca de
/// activos es de solo lectura — ver nota en MusicRepository.deleteSong)
struct SongRow: View {
    let song: Song
    var isCurrent = false

    var body: some View {
        HStack(spacing: 12) {
            albumArtView(song.albumArt, side: 48)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(song.title)
                        .font(.body)
                        .lineLimit(1)
                    if isCurrent {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption2)
                            .foregroundStyle(PolyTheme.primary)
                    }
                }
                Text("\(song.artist) • \(song.album)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func albumArtView(_ art: UIImage?, side: CGFloat) -> some View {
        if let art {
            Image(uiImage: art)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(PolyTheme.surface)
                .frame(width: side, height: side)
                .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
        }
    }
}

struct FolderListView: View {
    let folders: [Folder]
    var onFolderClick: (Folder) -> Void

    var body: some View {
        if folders.isEmpty {
            VStack { Spacer(); Text("No se encontraron carpetas").foregroundStyle(.secondary); Spacer() }
        } else {
            List(folders) { folder in
                Button { onFolderClick(folder) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(folder.name)
                        Text("\(folder.songCount) canciones • \(folder.path)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
            .listStyle(.plain)
        }
    }
}

struct ArtistListView: View {
    let artists: [Artist]
    var onArtistClick: (Artist) -> Void

    var body: some View {
        if artists.isEmpty {
            VStack { Spacer(); Text("No se encontraron artistas").foregroundStyle(.secondary); Spacer() }
        } else {
            List(artists) { artist in
                Button { onArtistClick(artist) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(artist.name)
                        Text("\(artist.songs.count) canciones")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
            .listStyle(.plain)
        }
    }
}

struct AlbumListView: View {
    let albums: [Album]
    var onAlbumClick: (Album) -> Void

    var body: some View {
        if albums.isEmpty {
            VStack { Spacer(); Text("No se encontraron álbumes").foregroundStyle(.secondary); Spacer() }
        } else {
            List(albums) { album in
                Button { onAlbumClick(album) } label: {
                    HStack(spacing: 12) {
                        if let art = album.artImage {
                            Image(uiImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(PolyTheme.surface)
                                .frame(width: 56, height: 56)
                                .overlay(Image(systemName: "opticaldisc").foregroundStyle(.secondary))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(album.title)
                            Text("\(album.artist) • \(album.songs.count) canciones")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
            .listStyle(.plain)
        }
    }
}

// =====================================================================
// MiniPlayer — equivalente del composable MiniPlayer (bottomBar del Scaffold)
// =====================================================================
struct MiniPlayerView: View {
    @EnvironmentObject private var player: AudioPlayerManager
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                artwork
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentSongTitle)
                        .font(.callout)
                        .lineLimit(1)
                    Text(player.currentArtistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 16) {
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                    }
                    Button { player.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(PolyTheme.cardFocus)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var artwork: some View {
        if let art = player.currentAlbumArt {
            Image(uiImage: art)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(PolyTheme.surface)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
        }
    }
}

// =====================================================================
// PetsVideoBannerView — equivalente de PetsVideoBanner (video 3D looped
// de tus mascotas, volumen 0) con AVKit en vez de ExoPlayer/PlayerView
// =====================================================================
struct PetsVideoBannerView: View {
    var body: some View {
        PetsVideoPlayer()
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
            .padding(.horizontal)
            .padding(.top, 16)
    }
}

/// Capa equivalente a AndroidView + PlayerView: AVPlayerLayer en un UIView
/// Reproduce `pets_animation.mov` empaquetado en el bundle (R.raw.pets_animation).
struct PetsVideoPlayer: UIViewRepresentable {
    final class BannerView: UIView {
        var player: AVPlayer?
    }

    func makeUIView(context: Context) -> BannerView {
        let container = BannerView()
        container.backgroundColor = .black

        // R.raw.pets_animation → recurso `pets_animation.mov` del bundle
        guard let url = Bundle.main.url(forResource: "pets_animation", withExtension: "mov")
        else { return container }

        let player = AVPlayer(url: url)
        player.volume = 0                        // banner mudo, como el exoPlayer
        let item = AVPlayerItem(url: url)
        item.actionAtItemEnd = .loop             // REPEAT_MODE_ONE
        player.replaceCurrentItem(with: item)
        player.play()
        container.player = player

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect // RESIZE_MODE_FIT (sin recortes)
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        container.layer.addSublayer(playerLayer)
        return container
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
}

/// Equivalente de RoundedCornerShape(16.dp)
struct RoundedCornerCard: InsettableShape {
    func inset(by amount: CGFloat) -> some InsettableShape {
        RoundedRectangle(cornerRadius: 16 + amount)
    }
}
