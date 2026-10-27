import UIKit

/// Equivalente iOS de com.poly.music.data.model.Album
struct Album: Identifiable, Hashable {
    let title: String
    let artist: String
    var artImage: UIImage? = nil       // Kotlin: artUri: String?
    let songs: [Song]

    var id: String { "\(artist)-\(title)" }
}
