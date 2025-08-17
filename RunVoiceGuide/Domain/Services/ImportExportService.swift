import Foundation
import UniformTypeIdentifiers
import Compression

@MainActor
final class ImportExportService: ObservableObject {
    static let shared = ImportExportService()
    
    @Published var isProcessing = false
    @Published var lastError: String?
    
    private init() {}
    
    // MARK: - Export
    
    func exportAudioAndPlacement() throws -> URL {
        isProcessing = true
        defer { isProcessing = false }
        
        let guides = CourseLoader.loadGuidePoints()
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDir = documentsDir.appendingPathComponent("audio")
        
        // Create export bundle directory in temporary location for sharing
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("RunVoiceGuide_Export_\(DateFormatter.filenameDateFormatter.string(from: Date())).rvgexport")
        
        // Remove existing export if any
        try? FileManager.default.removeItem(at: exportURL)
        try FileManager.default.createDirectory(at: exportURL, withIntermediateDirectories: true)
        
        // Create placement.json
        let placement = createPlacementData(from: guides)
        let placementData = try JSONEncoder().encode(placement)
        let placementURL = exportURL.appendingPathComponent("placement.json")
        try placementData.write(to: placementURL)
        
        // Copy audio files to export/audio/
        let exportAudioDir = exportURL.appendingPathComponent("audio")
        try FileManager.default.createDirectory(at: exportAudioDir, withIntermediateDirectories: true)
        
        var copiedAudioFiles = 0
        for guide in guides {
            guard !guide.audioId.isEmpty else { continue }
            
            let sourceURL = audioDir.appendingPathComponent(guide.audioId)
            let destURL = exportAudioDir.appendingPathComponent(guide.audioId)
            
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                copiedAudioFiles += 1
            } else {
                print("[ImportExport] Warning: Audio file not found: \(guide.audioId)")
            }
        }
        
        print("[ImportExport] Export completed: \(guides.count) guides, \(copiedAudioFiles) audio files")
        return exportURL
    }
    
    // MARK: - Import
    
    func importAudioAndPlacement(from importURL: URL) throws {
        isProcessing = true
        defer { isProcessing = false }
        
        // Validate structure and load placement.json
        let placementURL = importURL.appendingPathComponent("placement.json")
        guard FileManager.default.fileExists(atPath: placementURL.path) else {
            throw ImportExportError.invalidStructure("placement.json not found")
        }
        
        let placementData = try Data(contentsOf: placementURL)
        let placement = try JSONDecoder().decode(PlacementData.self, from: placementData)
        
        // Validate audio directory
        let importAudioDir = importURL.appendingPathComponent("audio")
        guard FileManager.default.fileExists(atPath: importAudioDir.path) else {
            throw ImportExportError.invalidStructure("audio directory not found")
        }
        
        // Copy audio files to Documents/audio/
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let targetAudioDir = documentsDir.appendingPathComponent("audio")
        
        // Ensure target audio directory exists
        if !FileManager.default.fileExists(atPath: targetAudioDir.path) {
            try FileManager.default.createDirectory(at: targetAudioDir, withIntermediateDirectories: true)
        }
        
        // Generate new UUIDs for audio files to avoid conflicts
        var audioIdMapping: [String: String] = [:]
        var copiedAudioFiles = 0
        
        for (_, placementInfo) in placement.guides {
            let oldAudioId = placementInfo.audioId
            guard !oldAudioId.isEmpty else { continue }
            
            let sourceURL = importAudioDir.appendingPathComponent(oldAudioId)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                print("[ImportExport] Warning: Audio file not found in import: \(oldAudioId)")
                continue
            }
            
            // Generate new audio ID
            let newAudioId = "\(UUID().uuidString).m4a"
            let targetURL = targetAudioDir.appendingPathComponent(newAudioId)
            
            // Copy with new name
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            audioIdMapping[oldAudioId] = newAudioId
            copiedAudioFiles += 1
            
            print("[ImportExport] Mapped audio: \(oldAudioId) → \(newAudioId)")
        }
        
        // Load existing guides and apply mappings
        var guides = CourseLoader.loadGuidePoints()
        var updatedGuides = 0
        
        for (guideIdString, placementInfo) in placement.guides {
            guard let guideId = UUID(uuidString: guideIdString) else { continue }
            
            if let guideIndex = guides.firstIndex(where: { $0.id == guideId }) {
                // Update existing guide
                if let newAudioId = audioIdMapping[placementInfo.audioId] {
                    guides[guideIndex] = GuidePoint(
                        id: guides[guideIndex].id,
                        latitude: guides[guideIndex].latitude,
                        longitude: guides[guideIndex].longitude,
                        radius: guides[guideIndex].radius,
                        message: guides[guideIndex].message,
                        audioId: newAudioId,
                        isCompleted: guides[guideIndex].isCompleted
                    )
                    updatedGuides += 1
                }
            } else {
                print("[ImportExport] Warning: Guide not found for ID: \(guideIdString)")
            }
        }
        
        // Save updated guides
        CourseLoader.saveGuidePoints(guides)
        
        print("[ImportExport] Import completed: \(copiedAudioFiles) audio files copied, \(updatedGuides) guides updated")
    }
    
    // MARK: - Helper Methods
    
    private func createPlacementData(from guides: [GuidePoint]) -> PlacementData {
        var guidesDict: [String: PlacementInfo] = [:]
        
        for guide in guides {
            if !guide.audioId.isEmpty {
                guidesDict[guide.id.uuidString] = PlacementInfo(
                    audioId: guide.audioId,
                    path: "audio/\(guide.audioId)"
                )
            }
        }
        
        return PlacementData(guides: guidesDict)
    }
    
    func clearLastError() {
        lastError = nil
    }
}

// MARK: - Data Structures

struct PlacementData: Codable {
    let guides: [String: PlacementInfo]
}

struct PlacementInfo: Codable {
    let audioId: String
    let path: String
}

// MARK: - Error Types

enum ImportExportError: LocalizedError {
    case invalidStructure(String)
    case audioFileNotFound(String)
    case zipCreationFailed
    case zipExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidStructure(let message):
            return "Invalid archive structure: \(message)"
        case .audioFileNotFound(let fileName):
            return "Audio file not found: \(fileName)"
        case .zipCreationFailed:
            return "Failed to create ZIP archive"
        case .zipExtractionFailed:
            return "Failed to extract ZIP archive"
        }
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}