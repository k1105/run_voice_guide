import SwiftUI
import CoreLocation

struct RecordingView: View {
    @State private var guides: [GuidePoint] = []
    @State private var showingNewGuideSheet = false
    @State private var editingGuide: GuidePoint?
    @StateObject private var audioService = AudioService()
    
    var body: some View {
        NavigationView {
            VStack {
                if guides.isEmpty {
                    emptyStateView
                } else {
                    guidesList
                }
            }
            .navigationTitle("Recording")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Guide") {
                        showingNewGuideSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .onAppear {
                loadGuides()
            }
            .sheet(isPresented: $showingNewGuideSheet) {
                GuideEditorSheet(
                    mode: .new(initial: nil),
                    onSave: { newGuide in
                        addGuide(newGuide)
                    },
                    onCancel: {
                        // Sheet handles temp recording cleanup
                    }
                )
            }
            .sheet(item: $editingGuide) { guide in
                GuideEditorSheet(
                    mode: .edit(guide: guide),
                    onSave: { updatedGuide in
                        updateGuide(updatedGuide)
                    },
                    onCancel: {
                        // Sheet handles temp recording cleanup
                    }
                )
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "mic.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Voice Guides")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first voice guide by tapping 'New Guide' above")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var guidesList: some View {
        List {
            ForEach(guides) { guide in
                GuideRowView(
                    guide: guide,
                    isPlaying: audioService.isPlaying && audioService.currentAudioId == guide.audioId,
                    onTap: {
                        editingGuide = guide
                    },
                    onPlay: {
                        if audioService.isPlaying && audioService.currentAudioId == guide.audioId {
                            audioService.stop()
                        } else {
                            audioService.activateSession()
                            audioService.playFromDocuments(audioId: guide.audioId)
                        }
                    }
                )
            }
            .onDelete(perform: deleteGuides)
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Guide Management
    
    private func loadGuides() {
        guides = CourseLoader.loadGuidePoints()
    }
    
    private func addGuide(_ guide: GuidePoint) {
        guides.append(guide)
        saveGuides()
    }
    
    private func updateGuide(_ updatedGuide: GuidePoint) {
        if let index = guides.firstIndex(where: { $0.id == updatedGuide.id }) {
            guides[index] = updatedGuide
            saveGuides()
        }
    }
    
    private func deleteGuides(at offsets: IndexSet) {
        guides.remove(atOffsets: offsets)
        saveGuides()
    }
    
    private func saveGuides() {
        CourseLoader.saveGuidePoints(guides)
    }
}

// MARK: - Guide Row View

private struct GuideRowView: View {
    let guide: GuidePoint
    let isPlaying: Bool
    let onTap: () -> Void
    let onPlay: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(guide.message.isEmpty ? "Untitled" : guide.message)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text("\(guide.latitude, specifier: "%.6f"), \(guide.longitude, specifier: "%.6f") (\(Int(guide.radius))m)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !guide.audioId.isEmpty {
                        audioBadge
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            
            if !guide.audioId.isEmpty {
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(isPlaying ? .orange : .blue)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
        }
    }
    
    private var audioBadge: some View {
        Text("Audio")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}

#Preview {
    RecordingView()
}