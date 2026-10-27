import AVFoundation
import MediaPlayer
import UIKit

/// =====================================================================
/// AudioPlayerManager — equivalente iOS de MusicService (ExoPlayer) +
/// MediaController en LibraryScreen.
///
///  Media3 (Android)                     AVFoundation (iOS)
///  ─────────────────────────────────────────────────────────
///  ExoPlayer.Builder + AudioAttributes  AVAudioSession .playback + AVPlayer
///  controller.setMediaItems(items, i)   player.rewind + cola propia (currentIndex)
///  controller.play/pause/seekTo         player.play/pause + seek(to:)
///  seekToNextMediaItem/Previous         next()/previous() con wrap (loop)
///  controller.addListener(position)     addPeriodicTimeObserver (500 ms, igual que el while/.delay(500))
///  player.addListener(onIsPlaying…)     NotificationCenter (time control / itemDidPlayToEndTime)
///  setHandleAudioBecomingNoisy          AVAudioSession.interruptionNotification
///  MediaSession (lockscreen)            MPNowPlayingInfoCenter + MPRemoteCommandCenter
/// =====================================================================
@MainActor
final class AudioPlayerManager: NSObject, ObservableObject {

    // ── Estado observable: espejo de los `remember { mutableStateOf }` de LibraryScreen ──
    @Published private(set) var currentSongTitle = ""
    @Published private(set) var currentArtistName = ""
    @Published private(set) var currentAlbumArt: UIImage?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentPosition: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private let player = AVPlayer()
    private var pendingSongs: [Song] = []
    private var currentIndex = 0
    private var timeObserver: Any?
    private var nowPlayingObserver: NSObjectProtocol?

    // ── Inicialización (equivale a onCreate de MusicService) ──
    override init() {
        super.init()
        configureAudioSession()

        // FIN DE PISTA → siguiente (loop de la cola, como el loop implícito de MediaController)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        // RUIDO/INTERRUPCIONES (equivale a setHandleAudioBecomingNoisy(true))
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        // Tick de 500 ms (equivale al `while (true) { …; delay(500) }` de LaunchedEffect)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                self?.currentPosition = time.seconds
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let nowPlayingObserver { NotificationCenter.default.removeObserver(nowPlayingObserver) }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        // Usage MEDIA + ContentType MUSIC + WakeMode LOCAL → categoría .playback
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    // ── Transporte ──────────────────────────────────────────────

    /// Equivalente de `playSong`: controller.setMediaItems(items, startIndex) + prepare + play
    func play(_ song: Song, in list: [Song]) {
        pendingSongs = list
        currentIndex = list.firstIndex { $0.id == song.id } ?? 0
        loadAndPlayCurrent()
        isPlaying = true
        updateNowPlaying()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func resume() {
        guard currentIndex < pendingSongs.count else { return }
        let ready = player.currentItem?.status == .readyToPlay
        if !ready { loadAndPlayCurrent() }
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func next() { advance(by: 1) }
    func previous() { advance(by: -1) }

    private func advance(by offset: Int) {
        guard !pendingSongs.isEmpty else { return }
        currentIndex = (currentIndex + offset + pendingSongs.count) % pendingSongs.count
        loadAndPlayCurrent()
        isPlaying = true
        updateNowPlaying()
    }

    /// controller.seekTo(pos)
    func seek(to seconds: TimeInterval) {
        let item = player.currentItem ?? makeItem(for: pendingSongs[currentIndex])
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        currentPosition = seconds
    }

    /// exitApp: mediaController.stop() + stopService
    func stop() {
        player.stop()
        pendingSongs.removeAll()
        currentIndex = 0
        currentSongTitle = ""
        currentArtistName = ""
        currentAlbumArt = nil
        isPlaying = false
        updateNowPlaying()
    }

    private func loadAndPlayCurrent() {
        let song = pendingSongs[currentIndex]
        let item = makeItem(for: song)
        player.replaceCurrentItem(with: item)
        player.play()

        currentSongTitle = song.title
        currentArtistName = song.artist
        currentAlbumArt = song.albumArt
        duration = item.duration.seconds.isFinite ? item.duration.seconds : song.duration
        currentPosition = 0
    }

    @objc private func itemDidFinish(_ notification: Notification) {
        next()
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOption(rawValue: optionsValue).contains(.shouldResume) {
                resume()
            }
        @unknown default:
            break
        }
    }

    // ── Media items con metadata de lockscreen (MediaSession) ──

    private func makeItem(for song: Song) -> AVPlayerItem {
        let item = AVPlayerItem(url: song.url)
        // Metadata de lockscreen (MediaSession en Media3) — pattern estándar AVFoundation
        var metadata = [
            AVMetadataItem.value(forKey: .commonIdentifier, commonString: song.title),
            AVMetadataItem.value(forKey: .commonIdentifier, commonString: song.artist),
            AVMetadataItem.value(forKey: .commonIdentifier, commonString: song.album),
        ]
        if let art = song.albumArt {
            metadata.append(AVMetadataItem.artworkItem(with: art, format: .jpeg))
        }
        item.assetDisplayMetadata = metadata
        return item
    }

    private func updateNowPlaying() {
        let info = MPNowPlayingInfoCenter.default()
        if !pendingSongs.isEmpty, let song = pendingSongs[safe: currentIndex] {
            info.nowPlayingInfo = [
                MPMediaItemPropertyTitle: song.title,
                MPMediaItemPropertyArtist: song.artist,
                MPMediaItemPropertyPlaybackDuration: song.duration,
                MPMediaItemPropertyElapsedPlaybackTime: currentPosition,
                MPNowPlayingPlaybackRateKey: isPlaying ? 1.0 : 0.0,
            ]
        } else {
            info.nowPlayingInfo = nil
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
