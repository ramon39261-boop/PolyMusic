import UIKit

/// Equivalente iOS de com.poly.music.data.model.Song
/// id: identificador persistente de MPMediaItem (persistentID) en vez del MediaStore _ID.
/// url: assetUrl real de la biblioteca de Apple Music / archivos locales.
struct Song: Identifiable, Hashable {
    let id: Int64
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval          // Kotlin: durationMs: Long → iOS: segundos (TimeInterval)
    let url: URL                       // Kotlin: uri: String → URL real del asset
    let folderPath: String
    var channelCount: Int = 2
    var albumArt: UIImage? = nil       // Kotlin: albumArtUri: String? → UIImage ya cargada

    var displayDuration: Int { Int(duration) }
}
