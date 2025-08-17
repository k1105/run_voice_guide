import Foundation
import CoreLocation

struct GuidePoint: Identifiable, Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let radius: Double
    let message: String
    let audioId: String
    let isCompleted: Bool
    
    init(id: UUID = UUID(), latitude: Double, longitude: Double, radius: Double = 10.0, message: String, audioId: String, isCompleted: Bool = false) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.message = message
        self.audioId = audioId
        self.isCompleted = isCompleted
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}