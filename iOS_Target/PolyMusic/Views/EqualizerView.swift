import SwiftUI

// =====================================================================
// EqualizerView — equivalente del composable EqualizerDialog
// (botones de presets de reverb + 10 sliders de banda con dB)
// =====================================================================
struct EqualizerView: View {
    @EnvironmentObject private var player: AudioPlayerManager
    @Environment(\.dismiss) private var dismiss

    private let effects = AudioEffectsManager.shared

    /// Niveles de banda en memoria local (equivale al `bandLevels by remember`)
    @State private var bandLevels: [Double] = []
    @State private var selectedReverb = 0
    @State private var didApplySettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if player.currentSongTitle.isEmpty {
                    // Mismo estado que el .kt: "Reproduce una canción para activar los efectos"
                    Text("Reproduce una canción para activar los efectos")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    reverbSection
                    Divider()
                    Text("Ecualizador de 10 Bandas:")
                        .font(.subheadline.bold())
                    eqSection
                }
            }
            .padding()
            .navigationTitle("Ecualizador & Reverberación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") {
                        effects.saveSettings()
                        didApplySettings = true
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedReverb = effects.currentReverbPreset
            bandLevels = (0..<effects.numberOfBands).map { effects.getBandGain(index: $0) }
        }
    }

    // ── Section: presets de reverb (reverbPresets take(3)/drop(3) del .kt) ──
    private var reverbSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reverberación Acústica de Estudio:")
                .font(.subheadline.bold())

            HStack(spacing: 8) {
                ForEach(effects.reverbPresets.filter { $0.id < 3 }) { preset in
                    presetButton(preset)
                }
            }
            HStack(spacing: 8) {
                ForEach(effects.reverbPresets.filter { $0.id >= 3 }) { preset in
                    presetButton(preset)
                }
            }
        }
    }

    private func presetButton(_ preset: AudioEffectsManager.ReverbPreset) -> some View {
        Button {
            selectedReverb = preset.id
            effects.setReverbPreset(preset.id)
        } label: {
            Text(preset.name)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selectedReverb == preset.id ? PolyTheme.cardFocus : PolyTheme.surface,
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .buttonStyle(.plain)
    }

    // ── Section: 10 sliders de banda (rows de 440.dp del .kt) ──
    private var eqSection: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(0..<effects.numberOfBands, id: \.self) { i in
                    HStack(spacing: 12) {
                        Text(effects.getBandLabel(index: i))
                            .font(.caption)
                            .frame(width: 52, alignment: .leading)

                        // Ganancia 0...1 nativa de AVAudioUnitEQ
                        // (en el .kt era un Short de -1500..1500 centi-dB)
                        Slider(
                            value: Binding(
                                get: { bandLevels[safe: i] ?? 0.5 },
                                set: { newValue in
                                    bandLevels[i] = newValue
                                    effects.setBandGain(index: i, gain: newValue)
                                }
                            ),
                            in: 0...1
                        )
                        .frame(width: 120)

                        Text(effects.dbLabel(gain: bandLevels[safe: i] ?? 0.5, index: i))
                            .font(.caption)
                            .frame(width: 56, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
