import Foundation
import AVFoundation
import UIKit

@MainActor
class AudioService: NSObject, ObservableObject {
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var currentPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    
    @Published var isPlaying = false
    @Published var currentAudioId: String?
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    func activateSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            print("[Audio] Session activated for playback")
        } catch {
            print("[Audio] Failed to activate session: \(error)")
        }
    }
    
    func deactivateSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("[Audio] Session deactivated")
        } catch {
            print("[Audio] Failed to deactivate session: \(error)")
        }
    }
    
    func play(audioId: String) {
        guard !isPlaying || currentAudioId != audioId else {
            print("[Audio] Already playing \(audioId), skipping")
            return
        }
        
        // If currently playing, fade out first
        if isPlaying {
            fadeOutCurrentAudio {
                self.startPlayback(audioId: audioId)
            }
        } else {
            startPlayback(audioId: audioId)
        }
    }
    
    private func startPlayback(audioId: String) {
        guard let url = Bundle.main.url(forResource: audioId, withExtension: "mp3") else {
            print("[Audio] Audio file not found: \(audioId).mp3")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            
            currentPlayer = player
            currentAudioId = audioId
            isPlaying = true
            
            player.play()
            print("[Audio] Started playing: \(audioId)")
            
        } catch {
            print("[Audio] Failed to create player for \(audioId): \(error)")
        }
    }
    
    private func fadeOutCurrentAudio(completion: @escaping () -> Void) {
        guard let player = currentPlayer, player.isPlaying else {
            completion()
            return
        }
        
        let fadeDuration: TimeInterval = 0.5
        let fadeSteps = 20
        let stepDuration = fadeDuration / Double(fadeSteps)
        let volumeStep = player.volume / Float(fadeSteps)
        
        var currentStep = 0
        
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            player.volume = max(0, player.volume - volumeStep)
            
            if currentStep >= fadeSteps || player.volume <= 0 {
                timer.invalidate()
                player.stop()
                player.volume = 1.0 // Reset volume for next use
                self.isPlaying = false
                self.currentAudioId = nil
                self.currentPlayer = nil
                completion()
            }
        }
    }
    
    func stop() {
        fadeTimer?.invalidate()
        currentPlayer?.stop()
        currentPlayer = nil
        currentAudioId = nil
        isPlaying = false
        print("[Audio] Stopped playback")
    }
    
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("[Audio] Interruption began")
            if isPlaying {
                currentPlayer?.pause()
            }
        case .ended:
            print("[Audio] Interruption ended")
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && currentPlayer != nil {
                    currentPlayer?.play()
                }
            }
        @unknown default:
            break
        }
    }
}

extension AudioService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if player == self.currentPlayer {
                self.isPlaying = false
                self.currentAudioId = nil
                self.currentPlayer = nil
                print("[Audio] Finished playing: \(flag ? "successfully" : "with error")")
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("[Audio] Decode error: \(error?.localizedDescription ?? "unknown")")
            if player == self.currentPlayer {
                self.isPlaying = false
                self.currentAudioId = nil
                self.currentPlayer = nil
            }
        }
    }
}