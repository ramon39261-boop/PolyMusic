import AVFoundation

/// =====================================================================
/// AudioEffectsManager — equivalente iOS de
/// com.poly.music.data.player.AudioEffectsManager
/// + los audiofx (Equalizer / EnvironmentalReverb / Virtualizer /
/// LoudnessEnhancer) de MusicService.
///
///  Android (android.media.audiofx)        AVFoundation (iOS)
///  ────────────────────────────────────────────────────────────────
///  Equalizer(sessionId, audioSession)     AVAudioUnitEQ (AUNBandEQ,
///                                         10 bandas ISO)
///  EnvironmentalReverb + 5 presets        AVAudioUnitReverb (AUNReverbUnit)
///  Virtualizer / BassBoost / Loudness     — sin equivalente directo en
///    (estática de refuerzo)                iOS; ver README
///  Short (-1500..1500 centi-dB)           Double 0...1 (ganancia de banda)
///  SharedPreferences "poly_audio_prefs"   UserDefaults "poly_audio_prefs"
///  System.loadLibrary("DPS") (libDPS.so)  dlopen("libDPS.dylib") — ver README
/// =====================================================================
final class AudioEffectsManager: NSObject {

    static let shared = AudioEffectsManager()

    private let engine = AVAudioEngine()
    private let mainMixer = AVAudioMixerNode() // hub global (equivale a la salida de la sesión)

    private(set) lazy var equalizer: AVAudioUnitEQ = {
        // AUNBandEQ en iOS expone 10 bandas con las frecuencias ISO estándar,
        // idénticas a las de Android: 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz
        let eq = AVAudioUnitEQ()
        eq.numberOfBands = 10
        return eq
    }()

    private(set) lazy var reverb: AVAudioUnitReverb = {
        let rev = AVAudioUnitReverb()
        rev.quality = .high
        rev.wetLevel = 0.0
        rev.dryLevel = 1.0
        return rev
    }()

    private let prefKeyReverb = "reverb_preset"
    private let prefKeyEQ = "eq_levels"

    // Frecuencias estándar ISO para el ecualizador de 10 bandas (idénticas al .kt)
    private let bandFrequencies = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    var numberOfBands: Int { equalizer.numberOfBands }

    func getBandLabel(index: Int) -> String {
        let hz = bandFrequencies.indices.contains(index) ? bandFrequencies[index] : 1000
        return hz >= 1000 ? "\(hz / 1000) kHz" : "\(hz) Hz"
    }

    // ── Ganancias de banda en formato nativo de AVAudioUnitEQ: 0...1 ──
    /// Equivalente de getBandLevel(index) (Short en centi-dB en Android)
    func getBandGain(index: Int) -> Double {
        guard let range = equalizer.bandLevelRange(lowerBandNumber: index) else { return 0.5 }
        return range.gain
    }

    /// Equivalente de setBandLevel(index, level)
    func setBandGain(index: Int, gain: Double) {
        guard let range = equalizer.bandLevelRange(lowerBandNumber: index) else { return }
        range.gain = gain
        equalizer.setGain(gain, forBandNumber: index)
    }

    /// dB para mostrar en la UI (equivalente al "± dB" del .kt): convierte
    /// la ganancia 0...1 a decibelios usando el rango de la banda.
    func dbLabel(gain: Double, index: Int) -> String {
        guard let range = equalizer.bandLevelRange(lowerBandNumber: index) else { return "0 dB" }
        let decibels = Int((range.value(gain: gain)).rounded())
        return decibels > 0 ? "+\(decibels) dB" : "\(decibels) dB"
    }

    // ── Presets de reverb (mismos nombres que AudioEffectsManager.kt) ──
    struct ReverbPreset: Identifiable {
        let id: Int
        let name: String
        let wet: Float        // wetLevel 0..1
        let decay: Float      // decayTime ms
        let preDelay: Float   // preDelay ms
        let roomSize: Float   // roomSize 0..1
    }

    let reverbPresets: [ReverbPreset] = [
        ReverbPreset(id: 0, name: "Sin",         wet: 0.0,  decay: 0,    preDelay: 0,   roomSize: 0.0),
        ReverbPreset(id: 1, name: "Estu",        wet: 0.05, decay: 300,  preDelay: 0,   roomSize: 0.2),
        ReverbPreset(id: 2, name: "Sala",        wet: 0.12, decay: 800,  preDelay: 40,  roomSize: 0.4),
        ReverbPreset(id: 3, name: "Auditorio /", wet: 0.25, decay: 2200, preDelay: 60,  roomSize: 0.7),
        ReverbPreset(id: 4, name: "Catedral /",  wet: 0.40, decay: 4500, preDelay: 100, roomSize: 1.0),
    ]

    var currentReverbPreset = 0

    /// Equivalente de setReverbPreset(presetIndex)
    func setReverbPreset(_ presetIndex: Int) {
        currentReverbPreset = presetIndex
        guard let preset = reverbPresets.first(where: { $0.id == presetIndex }) else { return }
        reverb.wetLevel = preset.wet
        reverb.decayTime = preset.decay
        reverb.preDelay = preset.preDelay
        reverb.roomSize = preset.roomSize
    }

    // ── Arranque del grafo de audio (onCreate de MusicService) ──
    func start() {
        do {
            // DSP externo: en Android, System.loadLibrary("DPS"); en iOS,
            // dlopen("libDPS.dylib", RTLD_NOW) cuando exista el motor para iOS.
            engine.attach(equalizer)
            engine.attach(reverb)
            engine.attach(mainMixer)
            engine.connect(equalizer, to: mainMixer, format: nil)
            engine.connect(reverb, to: mainMixer, format: nil)
            engine.connect(mainMixer, to: engine.outputNode, format: nil)
            engine.prepare()
            engine.start()
            loadSettings()
        } catch {
            print("AudioEffectsManager.start() fallo: \(error)")
        }
    }

    func stop() {
        engine.stop()
    }

    // ── Persistencia (SharedPreferences → UserDefaults, mismas claves) ──
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(currentReverbPreset, forKey: prefKeyReverb)

        let gains = (0..<numberOfBands).map {
            String(format: "%.3f", getBandGain(index: $0))
        }
        defaults.set(gains.joined(separator: ","), forKey: prefKeyEQ)
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        let reverbIndex = defaults.integer(forKey: prefKeyReverb)
        currentReverbPreset = reverbIndex
        setReverbPreset(reverbIndex)

        if let levelsStr = defaults.string(forKey: prefKeyEQ) {
            let parts = levelsStr.split(separator: ",").compactMap { Double($0) }
            guard parts.count == numberOfBands else { return }
            for (i, gain) in parts.enumerated() {
                setBandGain(index: i, gain: gain)
            }
        }
    }
}
