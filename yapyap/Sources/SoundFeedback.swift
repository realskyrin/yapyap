import AVFoundation
import Combine

class SoundFeedback {
    static let shared = SoundFeedback()

    private var startPlayer: AVAudioPlayer?
    private var stopPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadTheme(SettingsStore.shared.soundTheme)

        SettingsStore.shared.$soundTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in
                self?.loadTheme(theme)
            }
            .store(in: &cancellables)
    }

    private func loadTheme(_ theme: SoundTheme) {
        startPlayer = loadPlayer(named: theme.startFile)
        stopPlayer = loadPlayer(named: theme.stopFile)
    }

    private func loadPlayer(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("[SoundFeedback] Missing resource: \(name).wav")
            return nil
        }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }

    func playStart() {
        guard SettingsStore.shared.soundEnabled else { return }
        startPlayer?.currentTime = 0
        startPlayer?.play()
    }

    func playStop() {
        guard SettingsStore.shared.soundEnabled else { return }
        stopPlayer?.currentTime = 0
        stopPlayer?.play()
    }

    func previewStart() {
        startPlayer?.currentTime = 0
        startPlayer?.play()
    }

    func previewStop() {
        stopPlayer?.currentTime = 0
        stopPlayer?.play()
    }
}
