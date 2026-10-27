import Foundation
import MediaPlayer

/// Equivalente iOS de com.poly.music.data.repository.MusicRepository.
///
/// En Android se consulta MediaStore.Audio (IS_MUSIC != 0) vía ContentResolver.
/// En iOS la fuente equivalente es el Apple Asset Library (MPMediaLibrary).
/// El permiso READ_MEDIA_AUDIO equivale a NSAppleMusicUsageDescription
/// (Info.plist) + MPMediaLibrary.requestAuthorization.
final class MusicRepository {

    // Estados de autorización equivalentes al resultado del launcher de permiso
    enum AuthorizationState { case authorized, denied, notDetermined }

    static func requestAuthorization(_ completion: @escaping (AuthorizationState) -> Void) {
        MPMediaLibrary.requestAuthorization { status in
            let state: AuthorizationState
            switch status {
            case .authorized:
                state = .authorized
            case .denied:
                state = .denied
            @available(iOS 17.0, *)
            case .restricted:
                state = .denied
            @available(iOS 17.0, *)
            case .notDetermined:
                state = .notDetermined
            @unknown default:
                state = .denied
            }
            DispatchQueue.main.async { completion(state) }
        }
    }

    static var isAuthorized: Bool {
        MPMediaLibrary.authorizationStatus() == .authorized
    }

    /// Equivalente de fetchSongs(): todas las canciones de la biblioteca
    /// (IS_MUSIC == 1 viene implícito en MPMediaQuery.songs()).
    func fetchSongs() -> [Song] {
        let query = MPMediaQuery.songs()
        query.propertiesToFetch = [
            MPMediaItemPropertyTitle,
            MPMediaItemPropertyArtist,
            MPMediaItemPropertyAlbumTitle,
            MPMediaItemPropertyAlbumArtist,
            MPMediaItemPropertyCollectionTitle,
            MPMediaItemPropertyPlaybackDuration,
            MPMediaItemPropertyAssetURL,
            MPMediaItemPropertyPersistentID
        ]
        // Mismos defaults que en el cursor Android
        let items = query.items ?? []
        return items.compactMap { item in
            guard let url = item.assetUrl else { return nil }
            return Song(
                id: Int64(item.persistentID),
                title: item.title ?? "Desconocido",
                artist: item.artist ?? item.albumArtist ?? "Artista Desconocido",
                album: item.albumTitle ?? "Álbum Desconocido",
                duration: item.playbackDuration,
                url: url,
                folderPath: item.collectionTitle ?? "Desconocido", // ver nota en Folder.swift
                albumArt: albumArt(for: item)
            )
        }
    }

    /// Arte del álbum: MediaStore usaba ContentUris (content://media/external/audio/albumart).
    /// En iOS se obtiene vía MPMediaItemArtwork.
    private func albumArt(for item: MPMediaItem) -> UIImage? {
        MPMediaItem.artwork(forItem: item)?.image(forSize: CGSize(width: 512, height: 512))
    }

    // ------------------------------------------------------------------
    // Agrupaciones (grouping en memoria, igual que el código Kotlin)
    // ------------------------------------------------------------------

    func fetchFolders(songs: [Song]) -> [Folder] {
        Dictionary(grouping: songs, by: { $0.folderPath })
            .map { (path, songs) in
                Folder(
                    name: (path as NSString).lastPathComponent.isEmpty ? path : (path as NSString).lastPathComponent,
                    path: path,
                    songCount: songs.count,
                    songs: songs
                )
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func fetchArtists(songs: [Song]) -> [Artist] {
        Dictionary(grouping: songs, by: { $0.artist })
            .map { Artist(name: $0.key, songs: $0.value) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func fetchAlbums(songs: [Song]) -> [Album] {
        Dictionary(grouping: songs, by: { $0.album })
            .map { (album, albumSongs) in
                Album(
                    title: album,
                    artist: albumSongs.first?.artist ?? "Artista Desconocido",
                    artImage: albumSongs.first?.albumArt,
                    songs: albumSongs
                )
            }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    /// ⚠️ Diferencia de plataforma: en Android se borraba el archivo del
    /// dispositivo (File.delete + ContentResolver.delete). La biblioteca de
    /// activos de iOS es de SOLO LECTURA (no se puede borrar música del
    /// dispositivo desde la app). El botón "Eliminar" en la UI iOS queda
    /// como stub documentado; ver README.
    @discardableResult
    func deleteSong(_ song: Song) -> Bool {
        // No-op: MPMediaLibrary no permite eliminar pistas de música.
        print("deleteSong no disponible en iOS para la biblioteca de música: \(song.title)")
        return false
    }
}
