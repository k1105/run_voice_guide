import SwiftUI
import CoreLocation

struct HistoryDetailView: View {
    let run: RunEntity
    @StateObject private var storageService = StorageService.shared
    @State private var currentCourse: Course?
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TrackMapView(
                    track: trackCoordinates,
                    guides: mappedGuides,
                    start: startLocation,
                    endRadius: endRadius,
                    current: nil
                )
                .frame(height: 400)
                .cornerRadius(12)
                
                VStack(spacing: 16) {
                    runInfoSection
                    trackStatsSection
                    courseInfoSection
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
        .navigationTitle("Run Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Delete Run", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteRun()
            }
        } message: {
            Text("Are you sure you want to delete this run? This action cannot be undone.")
        }
        .onAppear {
            if currentCourse == nil {
                currentCourse = CourseLoader.loadDefaultCourse()
            }
        }
    }
    
    // MARK: - Computed Properties for TrackMapView
    
    private var trackCoordinates: [CLLocationCoordinate2D] {
        let trackPoints = storageService.getTrackPoints(for: run)
        return trackPoints
            .sorted { ($0.ts ?? Date.distantPast) < ($1.ts ?? Date.distantPast) }
            .map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }
    
    private var startLocation: CLLocationCoordinate2D? {
        return CLLocationCoordinate2D(latitude: run.startLat, longitude: run.startLng)
    }
    
    private var endRadius: CLLocationDistance? {
        return run.endRadius > 0 ? run.endRadius : nil
    }
    
    private var mappedGuides: [TrackMapView.GuidePin] {
        guard let course = currentCourse else { return [] }
        
        return course.guidePoints.map { guidePoint in
            TrackMapView.GuidePin(
                id: guidePoint.id.uuidString,
                coord: CLLocationCoordinate2D(
                    latitude: guidePoint.latitude,
                    longitude: guidePoint.longitude
                ),
                hasAudio: !guidePoint.audioId.isEmpty,
                label: guidePoint.message.isEmpty ? nil : guidePoint.message
            )
        }
    }
    
    // MARK: - UI Sections
    
    private var runInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Run Information")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(run.startedAt ?? Date(), formatter: dateTimeFormatter)
                        .font(.body)
                }
                
                Spacer()
                
                if let endedAt = run.endedAt {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Ended")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(endedAt, formatter: dateTimeFormatter)
                            .font(.body)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("In Progress")
                            .font(.body)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if let duration = runDuration {
                HStack {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(duration)
                        .font(.body)
                        .fontWeight(.semibold)
                }
            }
            
            HStack {
                Text("Start Location")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(run.startLat, specifier: "%.6f"), \(run.startLng, specifier: "%.6f")")
                    .font(.monospaced(.caption)())
            }
            
            if run.endRadius > 0 {
                HStack {
                    Text("End Radius")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(run.endRadius, specifier: "%.1f")m")
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var trackStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track Statistics")
                .font(.headline)
            
            let trackPoints = storageService.getTrackPoints(for: run)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Track Points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(trackPoints.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                if let firstPoint = trackPoints.first(where: { $0.ts != nil }),
                   let lastPoint = trackPoints.last(where: { $0.ts != nil }) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Tracking Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let trackingDuration = (lastPoint.ts!).timeIntervalSince(firstPoint.ts!)
                        Text(formatDuration(trackingDuration))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
            }
            
            if run.finishConsecutive > 0 {
                HStack {
                    Text("Finish Consecutive Hits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(run.finishConsecutive)")
                        .font(.body)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var courseInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Course Information")
                .font(.headline)
            
            if let course = currentCourse {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Course: \(course.name)")
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    if !course.description.isEmpty {
                        Text(course.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("\(course.guidePoints.count) guide points")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        if course.distance > 0 {
                            Text("\(course.distance, specifier: "%.1f")m distance")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("No course data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Methods
    
    private var runDuration: String? {
        guard let startedAt = run.startedAt else { return nil }
        let endTime = run.endedAt ?? Date()
        let duration = endTime.timeIntervalSince(startedAt)
        return formatDuration(duration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }
    
    // MARK: - Delete Function
    
    private func deleteRun() {
        // run.idがnilでないことを確認
        guard let runId = run.id else {
            print("[HistoryDetailView] Cannot delete run: run.id is nil")
            return
        }
        
        // 関連するTrackPointを明示的に削除
        let trackPoints = storageService.getTrackPoints(for: run)
        for trackPoint in trackPoints {
            storageService.persistentContainer.viewContext.delete(trackPoint)
        }
        
        // Runを削除
        storageService.persistentContainer.viewContext.delete(run)
        
        // 現在のRunが削除対象の場合はnilに設定
        if storageService.currentRun?.id == runId {
            storageService.currentRun = nil
        }
        
        // allRuns配列からも削除
        if let index = storageService.allRuns.firstIndex(where: { $0.id == runId }) {
            storageService.allRuns.remove(at: index)
        }
        
        // コンテキストを保存
        do {
            try storageService.persistentContainer.viewContext.save()
            print("[HistoryDetailView] Successfully deleted run: \(runId.uuidString)")
        } catch {
            print("[HistoryDetailView] Failed to delete run: \(error)")
        }
        
        // 前の画面に戻る
        dismiss()
    }
}

#Preview {
    // Create a mock run for preview
    let context = StorageService.shared.persistentContainer.viewContext
    let mockRun = RunEntity(context: context)
    mockRun.id = UUID()
    mockRun.startedAt = Date().addingTimeInterval(-3600)
    mockRun.endedAt = Date()
    mockRun.startLat = 35.6762
    mockRun.startLng = 139.6503
    mockRun.endRadius = 30.0
    mockRun.finishConsecutive = 3
    
    return NavigationView {
        HistoryDetailView(run: mockRun)
    }
}