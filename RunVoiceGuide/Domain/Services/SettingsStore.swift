import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    // MARK: - Published Properties
    
    @Published var guideTriggerRadius: Double {
        didSet {
            UserDefaults.standard.set(guideTriggerRadius, forKey: Keys.guideTriggerRadius)
            print("[Settings] Guide trigger radius updated: \(guideTriggerRadius)m")
        }
    }
    
    @Published var finishRadius: Double {
        didSet {
            UserDefaults.standard.set(finishRadius, forKey: Keys.finishRadius)
            print("[Settings] Finish radius updated: \(finishRadius)m")
        }
    }
    
    @Published var finishConsecutive: Int {
        didSet {
            UserDefaults.standard.set(finishConsecutive, forKey: Keys.finishConsecutive)
            print("[Settings] Finish consecutive updated: \(finishConsecutive)")
        }
    }
    
    @Published var bgmEnabled: Bool {
        didSet {
            UserDefaults.standard.set(bgmEnabled, forKey: Keys.bgmEnabled)
            print("[Settings] BGM enabled updated: \(bgmEnabled)")
        }
    }
    
    // MARK: - Keys
    
    private enum Keys {
        static let guideTriggerRadius = "guideTriggerRadius"
        static let finishRadius = "finishRadius"
        static let finishConsecutive = "finishConsecutive"
        static let bgmEnabled = "bgmEnabled"
    }
    
    // MARK: - Defaults
    
    private enum Defaults {
        static let guideTriggerRadius: Double = 40.0
        static let finishRadius: Double = 30.0
        static let finishConsecutive: Int = 3
        static let bgmEnabled: Bool = true
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load values from UserDefaults with defaults
        self.guideTriggerRadius = UserDefaults.standard.object(forKey: Keys.guideTriggerRadius) as? Double ?? Defaults.guideTriggerRadius
        self.finishRadius = UserDefaults.standard.object(forKey: Keys.finishRadius) as? Double ?? Defaults.finishRadius
        self.finishConsecutive = UserDefaults.standard.object(forKey: Keys.finishConsecutive) as? Int ?? Defaults.finishConsecutive
        self.bgmEnabled = UserDefaults.standard.object(forKey: Keys.bgmEnabled) as? Bool ?? Defaults.bgmEnabled
        
        print("[Settings] Loaded settings - Guide: \(guideTriggerRadius)m, Finish: \(finishRadius)m, Consecutive: \(finishConsecutive), BGM: \(bgmEnabled)")
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        guideTriggerRadius = Defaults.guideTriggerRadius
        finishRadius = Defaults.finishRadius
        finishConsecutive = Defaults.finishConsecutive
        bgmEnabled = Defaults.bgmEnabled
        print("[Settings] Reset to defaults")
    }
}