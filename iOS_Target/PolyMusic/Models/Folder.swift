import Foundation

/// Equivalente iOS de com.poly.music.data.model.Folder
///
/// Nota: la biblioteca de activos de iOS (MPMediaLibrary) no expone rutas de
/// carpeta de archivos como MediaStore (Data column). El equivalente práctico
/// es la propiedad `collection` (álbum/carpeta del archivo de música), que es
/// lo que el Asset Library muestra como origen del track.
struct Folder: Identifiable, Hashable {
    let name: String
    let path: String
    let songCount: Int
    let songs: [Song]

    var id: String { path }
}
