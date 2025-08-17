import Foundation

class CourseLoader {
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