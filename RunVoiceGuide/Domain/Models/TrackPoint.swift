import Foundation
import CoreLocation

struct TrackPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let speed: Double?
    let course: Double?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), latitude: Double, longitude: Double, altitude: Double? = nil, speed: Double? = nil, course: Double? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.speed = speed
        self.course = course
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}