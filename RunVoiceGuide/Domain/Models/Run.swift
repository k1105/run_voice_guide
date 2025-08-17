import Foundation

struct Run: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date?
    let distance: Double
    let duration: TimeInterval
    let averagePace: TimeInterval
    let trackPoints: [TrackPoint]
    let courseId: UUID?
    
    init(id: UUID = UUID(), startTime: Date = Date(), endTime: Date? = nil, distance: Double = 0, duration: TimeInterval = 0, averagePace: TimeInterval = 0, trackPoints: [TrackPoint] = [], courseId: UUID? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.duration = duration
        self.averagePace = averagePace
        self.trackPoints = trackPoints
        self.courseId = courseId
    }
}