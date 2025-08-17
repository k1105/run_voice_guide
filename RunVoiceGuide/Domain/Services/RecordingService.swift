import Foundation
import AVFoundation
import UIKit

@MainActor
final class RecordingService: NSObject, ObservableObject {
    static let shared = RecordingService()
    
    @Published var isRecording = false
    @Published var currentDuration: TimeInterval = 0
    @Published var hasPermission = false
    
    private var audioRecorder: AVAudioRecorder?
    private var durationTimer: Timer?
    private var currentRecordingId: UUID?
    private var previousAudioSessionCategory: AVAudioSession.Category?
    private var previousAudioSessionMode: AVAudioSession.Mode?
    private var previousAudioSessionOptions: AVAudioSession.CategoryOptions?
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    private override init() {
        super.init()
        setupNotifications()
        checkMicrophonePermission()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    private func checkMicrophonePermission() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                hasPermission = true
            case .denied:
                hasPermission = false
            case .undetermined:
                hasPermission = false
            @unknown default:
                hasPermission = false
            }
        } else {
            switch audioSession.recordPermission {
            case .granted:
                hasPermission = true
            case .denied:
                hasPermission = false
            case .undetermined:
                hasPermission = false
            @unknown default:
                hasPermission = false
            }
        }
    }
    
    // MARK: - Permission
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in
                        self.hasPermission = granted
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                audioSession.requestRecordPermission { granted in
                    Task { @MainActor in
                        self.hasPermission = granted
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
    func start() async throws -> Bool {
        guard !isRecording else { return false }
        
        // Check permission
        if !hasPermission {
            let granted = await requestMicrophonePermission()
            guard granted else {
                print("[Recording] Microphone permission denied")
                return false
            }
        }
        
        // Setup audio session
        try setupRecordingSession()
        
        // Create recording
        let recordingId = UUID()
        let tempURL = tempRecordingURL(for: recordingId)
        
        // Ensure temp directory exists
        try createTempDirectoryIfNeeded()
        
        // Configure recorder
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        
        guard audioRecorder?.record() == true else {
            print("[Recording] Failed to start recording")
            restoreAudioSession()
            return false
        }
        
        currentRecordingId = recordingId
        isRecording = true
        currentDuration = 0
        startDurationTimer()
        
        print("[Recording] Started recording to: \(tempURL)")
        return true
    }
    
    func stop() -> URL? {
        guard isRecording, let recorder = audioRecorder, let recordingId = currentRecordingId else {
            return nil
        }
        
        recorder.stop()
        stopDurationTimer()
        restoreAudioSession()
        
        isRecording = false
        audioRecorder = nil
        
        let tempURL = tempRecordingURL(for: recordingId)
        print("[Recording] Stopped recording, temp file at: \(tempURL)")
        
        return tempURL
    }
    
    func discard() {
        guard let recordingId = currentRecordingId else { return }
        
        if isRecording {
            audioRecorder?.stop()
            stopDurationTimer()
            restoreAudioSession()
            isRecording = false
        }
        
        // Delete temp file
        let tempURL = tempRecordingURL(for: recordingId)
        try? FileManager.default.removeItem(at: tempURL)
        
        audioRecorder = nil
        currentRecordingId = nil
        currentDuration = 0
        
        print("[Recording] Discarded recording")
    }
    
    func commit(toPermanentWith fileId: UUID) throws -> URL {
        guard let recordingId = currentRecordingId else {
            throw RecordingError.noActiveRecording
        }
        
        let tempURL = tempRecordingURL(for: recordingId)
        let permanentURL = permanentRecordingURL(for: fileId)
        
        // Ensure permanent directory exists
        try createPermanentDirectoryIfNeeded()
        
        // Move file
        try FileManager.default.moveItem(at: tempURL, to: permanentURL)
        
        currentRecordingId = nil
        currentDuration = 0
        
        print("[Recording] Committed recording to: \(permanentURL)")
        return permanentURL
    }
    
    // MARK: - Audio Session Management
    
    private func setupRecordingSession() throws {
        // Save current session state
        previousAudioSessionCategory = audioSession.category
        previousAudioSessionMode = audioSession.mode
        previousAudioSessionOptions = audioSession.categoryOptions
        
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: [])
        
        print("[Recording] Audio session configured for recording")
    }
    
    private func restoreAudioSession() {
        guard let previousCategory = previousAudioSessionCategory else { return }
        
        do {
            try audioSession.setCategory(
                previousCategory,
                mode: previousAudioSessionMode ?? .default,
                options: previousAudioSessionOptions ?? []
            )
            try audioSession.setActive(true, options: [])
            print("[Recording] Audio session restored")
        } catch {
            print("[Recording] Failed to restore audio session: \(error)")
        }
        
        previousAudioSessionCategory = nil
        previousAudioSessionMode = nil
        previousAudioSessionOptions = nil
    }
    
    // MARK: - Duration Timer
    
    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                self.currentDuration = recorder.currentTime
            }
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    // MARK: - File Management
    
    private func tempRecordingURL(for id: UUID) -> URL {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("recordings")
        return tempDir.appendingPathComponent("\(id.uuidString).m4a")
    }
    
    private func permanentRecordingURL(for fileId: UUID) -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDir = documentsDir.appendingPathComponent("audio")
        return audioDir.appendingPathComponent("\(fileId.uuidString).m4a")
    }
    
    private func createTempDirectoryIfNeeded() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("recordings")
        
        if !FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
    }
    
    private func createPermanentDirectoryIfNeeded() throws {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDir = documentsDir.appendingPathComponent("audio")
        
        if !FileManager.default.fileExists(atPath: audioDir.path) {
            try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("[Recording] Audio interruption began")
            if isRecording {
                audioRecorder?.pause()
            }
        case .ended:
            print("[Recording] Audio interruption ended")
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && isRecording {
                    audioRecorder?.record()
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleAppBackground(notification: Notification) {
        // Stop recording when app goes to background to avoid system termination
        if isRecording {
            print("[Recording] App backgrounded, stopping recording")
            discard()
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            print("[Recording] Finished recording: \(flag ? "successfully" : "with error")")
            if !flag {
                self.discard()
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            print("[Recording] Encode error: \(error?.localizedDescription ?? "unknown")")
            self.discard()
        }
    }
}

// MARK: - Error Types

enum RecordingError: LocalizedError {
    case noActiveRecording
    case permissionDenied
    case recordingFailed
    
    var errorDescription: String? {
        switch self {
        case .noActiveRecording:
            return "No active recording session"
        case .permissionDenied:
            return "Microphone permission denied"
        case .recordingFailed:
            return "Failed to start recording"
        }
    }
}
