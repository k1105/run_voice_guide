import Foundation

extension Notification.Name {
    static let guidePointsDidChange = Notification.Name("guidePointsDidChange")
}

class CourseLoader {
    // MARK: - GuidePoint Persistence
    
    static func loadGuidePoints() -> [GuidePoint] {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let courseURL = documentsDir.appendingPathComponent("course.json")
        
        guard FileManager.default.fileExists(atPath: courseURL.path) else {
            print("[CourseLoader] course.json not found, returning empty array")
            return []
        }
        
        do {
            let data = try Data(contentsOf: courseURL)
            let decoder = JSONDecoder()
            let guides = try decoder.decode([GuidePoint].self, from: data)
            print("[CourseLoader] Loaded \(guides.count) guide points from course.json")
            return guides
        } catch {
            print("[CourseLoader] Failed to load guide points: \(error)")
            return []
        }
    }
    
    static func saveGuidePoints(_ guides: [GuidePoint]) {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let courseURL = documentsDir.appendingPathComponent("course.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(guides)
            try data.write(to: courseURL)
            print("[CourseLoader] Saved \(guides.count) guide points to course.json")
            
            // Broadcast change notification
            NotificationCenter.default.post(name: .guidePointsDidChange, object: nil)
        } catch {
            print("[CourseLoader] Failed to save guide points: \(error)")
        }
    }
    
    static func rebindGuideAudioId(_ guideId: UUID, newAudioId: String) {
        var guides = loadGuidePoints()
        if let index = guides.firstIndex(where: { $0.id == guideId }) {
            guides[index] = GuidePoint(
                id: guides[index].id,
                latitude: guides[index].latitude,
                longitude: guides[index].longitude,
                radius: guides[index].radius,
                message: guides[index].message,
                audioId: newAudioId,
                isCompleted: guides[index].isCompleted
            )
            saveGuidePoints(guides)
            print("[CourseLoader] Rebound guide \(guideId) to audioId: \(newAudioId)")
        }
    }
    
    // MARK: - Course Loading
    
    static func loadDefaultCourse() -> Course? {
        guard let url = Bundle.main.url(forResource: "course", withExtension: "json") else {
            print("[CourseLoader] course.json not found in bundle")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            // Set up UUID decoding
            decoder.keyDecodingStrategy = .useDefaultKeys
            
            let courseData = try decoder.decode(CourseData.self, from: data)
            
            // Convert CourseData to Course
            let course = Course(
                id: courseData.id,
                name: courseData.name,
                description: courseData.description,
                distance: courseData.distance,
                estimatedDuration: courseData.estimatedDuration,
                guidePoints: courseData.guidePoints,
                createdAt: Date(),
                isActive: courseData.isActive
            )
            
            print("[CourseLoader] Loaded course: \(course.name) with \(course.guidePoints.count) guide points")
            return course
            
        } catch {
            print("[CourseLoader] Failed to load course: \(error)")
            return nil
        }
    }
}

// Helper struct that matches the JSON structure
private struct CourseData: Codable {
    let id: UUID
    let name: String
    let description: String
    let distance: Double
    let estimatedDuration: TimeInterval
    let isActive: Bool
    let guidePoints: [GuidePoint]
}