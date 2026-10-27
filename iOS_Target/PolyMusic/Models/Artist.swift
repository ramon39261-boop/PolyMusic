import Foundation

/// Equivalente iOS de com.poly.music.data.model.Artist
struct Artist: Identifiable, Hashable {
    let name: String
    let songs: [Song]

    var id: String { name }
}
