# PolyMusic — Port a iOS (SwiftUI + AVFoundation)

Estructura equivalente 1:1 de la app Android (Kotlin + Jetpack Compose + Media3)
a una app nativa de iOS. Cada archivo Swift incluye comentarios que rematan al
equivalente Kotlin de donde se tradujo.

## Árbol de archivos

```
iOS_Target/PolyMusic/
├── PolyMusicApp.swift          ← MainActivity.kt (ComponentActivity + setContent)
├── AppTheme.swift              ← ui/theme/Theme.kt (PolyTheme, mismos colores)
├── Models/
│   ├── Song.swift              ← data/model/Song.kt
│   ├── Album.swift             ← data/model/Album.kt
│   ├── Artist.swift            ← data/model/Artist.kt
│   └── Folder.swift          ← data/model/Folder.kt
├── Data/
│   └── MusicRepository.swift   ← data/repository/MusicRepository.kt
├── Player/
│   ├── AudioPlayerManager.swift ← data/player/MusicService.kt (ExoPlayer → AVPlayer)
│   └── AudioEffectsManager.swift← data/player/AudioEffectsManager.kt + audiofx
└── Views/
    ├── LibraryView.swift       ← ui/library/LibraryScreen.kt
    ├── Lists.swift             ← SongList/FolderList/ArtistList/AlbumList +
    │                              MiniPlayer + PetsVideoBanner (ExoPlayer → AVKit)
    ├── SongDetailView.swift    ← SongDetailScreen
    ├── FullPlayerView.swift    ← FullPlayerScreen
    └── EqualizerView.swift     ← EqualizerDialog
```

## Mapeo de APIs (Android → iOS)

| Android (Media3) | iOS (AVFoundation) |
|---|---|
| `ExoPlayer` + `AudioAttributes(MUSIC)` | `AVPlayer` + `AVAudioSession(.playback)` |
| `MediaSession` / `MediaController` | `AudioPlayerManager` (ObservableObject) + `MPNowPlayingInfoCenter` |
| `DefaultRenderersFactory` + FFmpeg 6.0 | decodificadores nativos de `AVAsset` (codec HEVC/AC3 incluidos) |
| `MediaStore.Audio` (IS_MUSIC≠0) | `MPMediaLibrary` + `MPMediaQuery.songs()` |
| `READ_MEDIA_AUDIO` + launcher | `NSAppleMusicUsageDescription` + `MPMediaLibrary.requestAuthorization` |
| `android.media.audiofx.Equalizer` (10 bandas, centi-dB) | `AVAudioUnitEQ` (AUNBandEQ, 10 bandas ISO, ganancia 0...1) |
| `EnvironmentalReverb` (5 presets) | `AVAudioUnitReverb` (mismos 5 presets remapeados) |
| `Virtualizer` / `BassBoost` / `LoudnessEnhancer` | sin equivalente directo en iOS (ver nota 3) |
| `SharedPreferences("poly_audio_prefs")` | `UserDefaults` con las **mismas claves** |
| `System.loadLibrary("DPS")` (libDPS.so) | `dlopen("libDPS.dylib", RTLD_NOW)` cuando exista el motor para iOS |
| `content://media/.../albumart` + `ContentUris` | `MPMediaItemArtwork.image(forSize:)` |
| `ExoPlayer` banner `R.raw.pets_animation` (volumen 0, loop) | `AVPlayer` del recurso `pets_animation.mov` (volumen 0, `.loop`) |
| Coil `AsyncImage` | `Image(uiImage:)` (la portada ya viene descargada) |
| `Slider` -1500..1500 | `Slider` 0...1 (conversión a dB en el manager) |

## Notas de diferencia de plataforma (importante)

1. **Carpeta de canciones** — MediaStore expone la ruta del archivo (`DATA`); el
   Asset Library de iOS **no expone rutas**, por eso `folderPath` se mapea a la
   propiedad `collectionTitle` (la "carpeta"/colección del track).

2. **Eliminar canciones** — En Android el app borra el archivo del dispositivo
   (`File.delete` + `ContentResolver.delete`). La biblioteca de música de iOS es
   **de solo lectura** desde una app, así que `MusicRepository.deleteSong()` es un
   stub documentado y la UI no muestra el botón de borrar (igual que en `SongRow`).

3. **Virtualizer / BassBoost / LoudnessEnhancer** — no existen en iOS. El
   `AudioEffectsManager` solo mapea EQ + Reverb. Si el motor externo DPS
   (`libDPS.dylib`) trae sus propios DSP, hay que enlazarlo con `dlopen` y
   conectarlo en el grafo del `AVAudioEngine` (hueco comentado en `start()`).

4. **Permiso en Info.plist** — añadir:
   ```xml
   <key>NSAppleMusicUsageDescription</key>
   <string>PolyMusic necesita acceso a tu biblioteca de música para reproducirla.</string>
   ```

5. **Recurso del banner** — añadir `pets_animation.mov` al bundle
   (equivalente a `R.raw.pets_animation`).

6. **Cargar efectos** — llamar a `AudioEffectsManager.shared.start()` al
   arrancar (equivalente al `onCreate` de `MusicService`).
