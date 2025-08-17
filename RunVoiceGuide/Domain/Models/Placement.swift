import Foundation

struct Placement: Identifiable, Codable {
    let id: UUID
    let runId: UUID
    let courseId: UUID
    let rank: Int
    let totalParticipants: Int
    let completionTime: TimeInterval
    let achievedAt: Date
    
    init(id: UUID = UUID(), runId: UUID, courseId: UUID, rank: Int, totalParticipants: Int, completionTime: TimeInterval, achievedAt: Date = Date()) {
        self.id = id
        self.runId = runId
        self.courseId = courseId
        self.rank = rank
        self.totalParticipants = totalParticipants
        self.completionTime = completionTime
        self.achievedAt = achievedAt
    }
    
    var percentile: Double {
        guard totalParticipants > 0 else { return 0 }
        return Double(totalParticipants - rank + 1) / Double(totalParticipants) * 100
    }
}