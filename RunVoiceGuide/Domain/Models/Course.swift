import Foundation

struct Course: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let distance: Double
    let estimatedDuration: TimeInterval
    let guidePoints: [GuidePoint]
    let createdAt: Date
    let isActive: Bool
    
    init(id: UUID = UUID(), name: String, description: String = "", distance: Double = 0, estimatedDuration: TimeInterval = 0, guidePoints: [GuidePoint] = [], createdAt: Date = Date(), isActive: Bool = true) {
        self.id = id
        self.name = name
        self.description = description
        self.distance = distance
        self.estimatedDuration = estimatedDuration
        self.guidePoints = guidePoints
        self.createdAt = createdAt
        self.isActive = isActive
    }
}