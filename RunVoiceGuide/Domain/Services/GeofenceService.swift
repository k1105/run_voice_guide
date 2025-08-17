import Foundation
import CoreLocation

@MainActor
class GeofenceService: ObservableObject {
    private var triggeredGuidePoints: Set<UUID> = []
    private let hysteresisFactor: Double = 1.5
    
    func checkHits(at location: CLLocation, guidePoints: [GuidePoint]) -> [GuidePoint] {
        var hits: [GuidePoint] = []
        
        for guidePoint in guidePoints {
            let distance = location.distance(from: CLLocation(
                latitude: guidePoint.latitude,
                longitude: guidePoint.longitude
            ))
            
            let triggerRadius = guidePoint.radius
            let isWithinRadius = distance <= triggerRadius
            let isAlreadyTriggered = triggeredGuidePoints.contains(guidePoint.id)
            let hysteresisRadius = triggerRadius * hysteresisFactor
            let isOutsideHysteresis = distance > hysteresisRadius
            
            // Reset trigger if we've moved outside the hysteresis radius
            if isAlreadyTriggered && isOutsideHysteresis {
                triggeredGuidePoints.remove(guidePoint.id)
                print("[Geofence] Reset trigger for guide point \(guidePoint.id) - distance: \(distance)m, hysteresis: \(hysteresisRadius)m")
            }
            
            // Trigger if within radius and not already triggered
            if isWithinRadius && !triggeredGuidePoints.contains(guidePoint.id) {
                triggeredGuidePoints.insert(guidePoint.id)
                hits.append(guidePoint)
                print("[Geofence] Hit guide point \(guidePoint.id) - distance: \(distance)m, radius: \(triggerRadius)m")
            }
        }
        
        return hits
    }
    
    func reset() {
        triggeredGuidePoints.removeAll()
        print("[Geofence] Reset all triggered guide points")
    }
    
    func getTriggeredIds() -> Set<UUID> {
        return triggeredGuidePoints
    }
}