import SwiftUI
import AVKit

/// =====================================================================
/// LibraryView — equivalente iOS de com.poly.music.ui.library.LibraryScreen
/// Mantiene el mismo diseño minimalista: banner de video, fila de tabs,
/// listas, mini-player fijo y player a pantalla completa.
/// =====================================================================
struct LibraryView: View {
    @EnvironmentObject private var player: AudioPlayerManager

    // Estados de UI (equivalentes a los `remember { mutableStateOf }` de LibraryScreen)
    @State private var selectedTab = 0
    private let tabs = ["Canciones", "Carpetas", "Artistas", "Álbumes"]

    @State private var songs: [Song] = []
    @State private var folders: [Folder] = []
    @State private var artists: [Artist] = []
    @State private var albums: [Album] = []
    @State private var hasPermission = false

    // Navegación a detalle (activeFolder / activeArtist / activeAlbum)
    @State private var activeFolder: Folder? = nil
    @State private var activeArtist: Artist? = nil
    @State private var activeAlbum: Album? = nil

    @State private var showFullPlayer = false
    @State private var showEqualizer = false

    private let repository = MusicRepository()

    var body: some View {
        Group {
            if activeFolder != nil {
                SongDetailView(
                    title: activeFolder!.name,
                    subtitle: "Ruta: \(activeFolder!.path)",
                    songs: activeFolder!.songs,
                    onClose: { activeFolder = nil },
                    onPlayAll: { playSong($0, in: activeFolder!.songs) }
                )
            } else if activeArtist != nil {
                SongDetailView(
                    title: activeArtist!.name,
                    subtitle: "\(activeArtist!.songs.count) canciones",
                    songs: activeArtist!.songs,
                    onClose: { activeArtist = nil },
                    onPlayAll: { playSong($0, in: activeArtist!.songs) }
                )
            } else if activeAlbum != nil {
                SongDetailView(
                    title: activeAlbum!.title,
                    subtitle: "Artista: \(activeAlbum!.artist) • \(activeAlbum!.songs.count) canciones",
                    songs: activeAlbum!.songs,
                    onClose: { activeAlbum = nil },
                    onPlayAll: { playSong($0, in: activeAlbum!.songs) }
                )
            } else {
                mainContent
            }
        }
        .onAppear(perform: requestAuthorization)
        .fullScreenCover(isPresented: $showFullPlayer) {
            FullPlayerView(onClose: { showFullPlayer = false })
        }
        .sheet(isPresented: $showEqualizer) {
            EqualizerView()
                .presentationDetents([.medium, .large])
        }
    }

    // ── Scaffold de LibraryScreen ──
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Título + acciones (TopAppBar)
            HStack {
                Text("PolyMusic Audiophile")
                    .font(.title3.bold())
                Spacer()
                Button {
                    showEqualizer = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                Button {
                    player.stop()
                    AudioEffectsManager.shared.stop()
                } label: {
                    Image(systemName: "power")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Banner de video 3D con tus mascotas
            PetsVideoBannerView()

            // ScrollableTabRow → Picker segmentado minimalista
            Picker("", selection: $selectedTab) {
                ForEach(tabs.indices, id: \.self) { i in
                    Text(tabs[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)

            // when (selectedTab) { … }
            Group {
                switch selectedTab {
                case 0:
                    SongListView(
                        songs: songs,
                        onSongClick: { playSong($0, in: songs) }
                    )
                case 1:
                    FolderListView(folders: folders) { activeFolder = $0 }
                case 2:
                    ArtistListView(artists: artists) { activeArtist = $0 }
                default:
                    AlbumListView(albums: albums) { activeAlbum = $0 }
                }
            }

            // MiniPlayer (bottomBar del Scaffold)
            if !player.currentSongTitle.isEmpty {
                MiniPlayerView(onOpen: { showFullPlayer = true })
            }
        }
        .background(PolyTheme.background)
    }

    // ── playSong: mediaController.setMediaItems(items, startIndex) + play ──
    private func playSong(_ song: Song, in list: [Song]) {
        player.play(song, in: list)
    }

    // ── Permiso de biblioteca musical (READ_MEDIA_AUDIO) ──
    private func requestAuthorization() {
        MusicRepository.requestAuthorization { state in
            guard state == .authorized else {
                hasPermission = false
                return
            }
            hasPermission = true
            loadMusic()
        }
    }

    // ── loadMusic(context) { s, f, ar, al } ──
    private func loadMusic() {
        let s = repository.fetchSongs()
        songs = s
        folders = repository.fetchFolders(songs: s)
        artists = repository.fetchArtists(songs: s)
        albums = repository.fetchAlbums(songs: s)
    }
}
