import Foundation
import CoreLocation

@MainActor
class AutoFinishJudge: ObservableObject {
    @Published var shouldFinish = false
    @Published var consecutiveHits = 0
    
    private var startLatitude: Double
    private var startLongitude: Double
    private let endRadius: Double
    private let requiredConsecutiveHits: Int
    private var currentConsecutiveCount = 0
    
    init(startLatitude: Double, startLongitude: Double, endRadius: Double = 30.0, requiredConsecutiveHits: Int = 3) {
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endRadius = endRadius
        self.requiredConsecutiveHits = requiredConsecutiveHits
        
        print("[AutoFinishJudge] Initialized with start: (\(startLatitude), \(startLongitude)), radius: \(endRadius)m, required hits: \(requiredConsecutiveHits)")
    }
    
    func processLocationUpdate(_ location: CLLocation) {
        let startLocation = CLLocation(latitude: startLatitude, longitude: startLongitude)
        let distance = location.distance(from: startLocation)
        
        if distance <= endRadius {
            currentConsecutiveCount += 1
            consecutiveHits = currentConsecutiveCount
            
            print("[AutoFinishJudge] Hit \(currentConsecutiveCount)/\(requiredConsecutiveHits) - distance: \(distance)m")
            
            if currentConsecutiveCount >= requiredConsecutiveHits {
                shouldFinish = true
                print("[AutoFinishJudge] 🏁 Should finish! Consecutive hits: \(currentConsecutiveCount)")
            }
        } else {
            if currentConsecutiveCount > 0 {
                print("[AutoFinishJudge] Reset consecutive count (was \(currentConsecutiveCount)) - distance: \(distance)m")
            }
            currentConsecutiveCount = 0
            consecutiveHits = 0
        }
    }
    
    func reset() {
        currentConsecutiveCount = 0
        consecutiveHits = 0
        shouldFinish = false
        print("[AutoFinishJudge] Reset state")
    }
    
    func updateStartLocation(latitude: Double, longitude: Double) {
        self.startLatitude = latitude
        self.startLongitude = longitude
        reset()
        print("[AutoFinishJudge] Updated start location to: (\(latitude), \(longitude))")
    }
    
    var startLocation: CLLocation {
        CLLocation(latitude: startLatitude, longitude: startLongitude)
    }
    
    var distanceToStart: Double? {
        return nil // Will be calculated in processLocationUpdate
    }
}