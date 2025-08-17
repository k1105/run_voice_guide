import SwiftUI

struct HistoryView: View {
    @StateObject private var storageService = StorageService.shared
    
    var body: some View {
        NavigationView {
            VStack {
                if storageService.allRuns.isEmpty {
                    VStack {
                        Text("No Runs Yet")
                            .font(.largeTitle)
                            .padding()
                        
                        Text("Start your first run to see it here!")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(storageService.allRuns, id: \.id) { run in
                            RunHistoryRow(run: run)
                        }
                        .onDelete(perform: deleteRuns)
                    }
                }
            }
            .navigationTitle("History")
            .onAppear {
                storageService.loadAllRuns()
            }
        }
    }
    
    private func deleteRuns(offsets: IndexSet) {
        for index in offsets {
            storageService.deleteRun(storageService.allRuns[index])
        }
    }
}

struct RunHistoryRow: View {
    let run: RunEntity
    @State private var trackPointCount: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Run \(run.id?.uuidString.prefix(8) ?? "unknown")")
                        .font(.headline)
                    
                    Text("Started: \(run.startedAt ?? Date(), formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let endedAt = run.endedAt {
                        Text("Ended: \(endedAt, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("In Progress")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(trackPointCount) points")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if let duration = runDuration {
                        Text(duration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text("Start: \(run.startLat, specifier: "%.4f"), \(run.startLng, specifier: "%.4f")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .onAppear {
            loadTrackPointCount()
        }
    }
    
    private var runDuration: String? {
        guard let startedAt = run.startedAt else { return nil }
        let endTime = run.endedAt ?? Date()
        let duration = endTime.timeIntervalSince(startedAt)
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func loadTrackPointCount() {
        let trackPoints = StorageService.shared.getTrackPoints(for: run)
        trackPointCount = trackPoints.count
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

#Preview {
    HistoryView()
}