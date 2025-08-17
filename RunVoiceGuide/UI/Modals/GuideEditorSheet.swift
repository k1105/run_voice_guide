import SwiftUI
import MapKit
import CoreLocation
import AVFoundation

// MARK: - AudioPreviewDelegate
private class AudioPreviewDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "unknown")")
        onFinish?()
    }
}

struct GuideEditorSheet: View {
    enum Mode {
        case new(initial: CLLocationCoordinate2D?)
        case edit(guide: GuidePoint)
    }
    
    let mode: Mode
    let defaultRadius: CLLocationDistance
    let onSave: (GuidePoint) -> Void
    let onCancel: (() -> Void)?
    let onDelete: ((GuidePoint) -> Void)?  // 削除用のコールバックを追加
    
    @State private var oneShotFetcher = OneShotLocationFetcher()
    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var radius: CLLocationDistance
    @State private var label: String
    @State private var cameraPosition: MapCameraPosition
    @State private var audioId: String?
    @State private var tempRecordingURL: URL?
    @State private var previewPlayer: AVAudioPlayer?
    private let previewDelegate = AudioPreviewDelegate()
    @State private var isPreviewing = false
    @State private var showingPermissionAlert = false
    @State private var showingLocationAlert = false
    @State private var showingDeleteAlert = false  // 削除確認用

    @State private var isFetchingGPS = false   // ← 連打防止のみ残す

    @StateObject private var recordingService = RecordingService.shared
    @Environment(\.dismiss) private var dismiss
    
    init(
        mode: Mode,
        defaultRadius: CLLocationDistance = 40,
        onSave: @escaping (GuidePoint) -> Void,
        onCancel: (() -> Void)? = nil,
        onDelete: ((GuidePoint) -> Void)? = nil  // 削除用のコールバックを追加
    ) {
        self.mode = mode
        self.defaultRadius = defaultRadius
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        
        switch mode {
        case .new(let initial):
            let coord = initial ?? CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
            let initialRadius = SettingsStore.shared.guideTriggerRadius
            let existingGuides = CourseLoader.loadGuidePoints()
            let nextNumber = existingGuides.count + 1
            let nextLabel = String(format: "#%02d", nextNumber)
            
            self._selectedCoordinate = State(initialValue: coord)
            self._radius = State(initialValue: initialRadius)
            self._label = State(initialValue: nextLabel)
            self._audioId = State(initialValue: nil)
            self._cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )))
        case .edit(let guide):
            self._selectedCoordinate = State(initialValue: guide.coordinate)
            self._radius = State(initialValue: guide.radius)
            self._label = State(initialValue: guide.message)
            self._audioId = State(initialValue: guide.audioId.isEmpty ? nil : guide.audioId)
            self._cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: guide.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )))
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    formView
                }
            }
            .navigationTitle(isNewMode ? "New Guide" : "Edit Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        handleCancel()
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if case .edit = mode {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button("Save") {
                        handleSave()
                    }
                    .disabled(!isValidForSave)
                }
            }
        }
        .alert("Microphone Permission", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Microphone access is required to record guide audio. Please enable it in Settings.")
        }
        .alert("Location Not Available", isPresented: $showingLocationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Current location is not available. Please ensure location services are enabled and try again.")
        }
        .alert("Delete Guide", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if case .edit(let guide) = mode {
                    onDelete?(guide)
                }
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this guide point?")
        }
        .onAppear {
            // Newモード & 初期座標なし → 可能なら一発取得で初期化
            if case .new(let initial) = mode, initial == nil {
                oneShotFetcher.requestLocation { loc in
                    guard let loc = loc else { return }
                    DispatchQueue.main.async {
                        self.selectedCoordinate = loc.coordinate
                        self.cameraPosition = .region(MKCoordinateRegion(
                            center: loc.coordinate,
                            latitudinalMeters: 1000,
                            longitudinalMeters: 1000
                        ))
                    }
                }
            }
        }
        .onDisappear {
            // ここでは何もしない（LocationServiceは触らない）
            cleanupAudio()
        }
    }
    
    private var isNewMode: Bool {
        if case .new = mode { return true }
        return false
    }
    
    private var isValidForSave: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && audioId != nil
    }
    
    private var mapView: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                Annotation("Guide Point", coordinate: selectedCoordinate, anchor: .bottom) {
                    pinView
                }
                
                MapCircle(center: selectedCoordinate, radius: radius)
                    .foregroundStyle(.blue.opacity(0.15))
                    .stroke(.blue.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapPitchToggle()
                MapUserLocationButton()
            }
            .onTapGesture { location in
                if let coordinate = proxy.convert(location, from: .local) {
                    selectedCoordinate = coordinate
                    withAnimation(.easeInOut(duration: 0.3)) {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: coordinate,
                            latitudinalMeters: 1000,
                            longitudinalMeters: 1000
                        ))
                    }
                }
            }
        }
        .frame(height: 250)
    }
    
    private var pinView: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.title)
                .foregroundColor(.red)
                .background(Color.white.clipShape(Circle()))
            
            Text("Guide")
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.9))
                .cornerRadius(4)
                .shadow(radius: 1)
        }
    }
    
    private var formView: some View {
        VStack(spacing: 20) {
            // Label Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Guide Message")
                    .font(.headline)
                
                TextField("Enter guide message", text: $label)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Map Section
            mapView
            
            // Use Current GPS Button
            Button(action: {
                Task { await useCurrentGPS() }
            }) {
                if isFetchingGPS {
                    ProgressView().progressViewStyle(.circular).frame(maxWidth: .infinity)
                } else {
                    Text("Use Current GPS").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isFetchingGPS)
            
            // Coordinates Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Coordinates")
                    .font(.headline)
                
                HStack {
                    Text("Lat:")
                    Text("\(selectedCoordinate.latitude, specifier: "%.6f")")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                }
                
                HStack {
                    Text("Lng:")
                    Text("\(selectedCoordinate.longitude, specifier: "%.6f")")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                }
            }
            
            // Radius Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Radius: \(Int(radius))m")
                    .font(.headline)
                
                Stepper(value: $radius, in: 10...200, step: 5) {
                    EmptyView()
                }
                
                Slider(value: $radius, in: 10...200, step: 5) {
                    Text("Radius")
                } minimumValueLabel: {
                    Text("10m")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("200m")
                        .font(.caption)
                }
            }
            
            // Recording Section
            recordingSection
        }
        .padding()
    }
    
    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Recording")
                .font(.headline)
            
            if !recordingService.isRecording && tempRecordingURL == nil && audioId == nil {
                // No recording state
                Button("Start Recording") {
                    startRecording()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            } else if recordingService.isRecording {
                // Currently recording
                VStack(spacing: 8) {
                    Text("Recording: \(formatDuration(recordingService.currentDuration))")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    HStack(spacing: 12) {
                        Button("Stop & Keep") {
                            stopRecording()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Cancel") {
                            cancelRecording()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else if tempRecordingURL != nil {
                // Recorded but not committed
                VStack(spacing: 8) {
                    Text("Recording ready")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    HStack(spacing: 12) {
                        Button(isPreviewing ? "Stop" : "Preview") {
                            if isPreviewing {
                                stopPreview()
                            } else if let url = tempRecordingURL {
                                startPreview(url: url)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Re-record") {
                            reRecord()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Use This Take") {
                            commitRecording()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else if audioId != nil {
                // Audio committed
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Audio recorded")
                            .foregroundColor(.green)
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Button(isPreviewing ? "Stop" : "Preview") {
                            if isPreviewing {
                                stopPreview()
                            } else {
                                previewCommittedAudio()
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Re-record") {
                            reRecord()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
    
    // MARK: - GPS Helpers
    // LocationService を使わず OneShotLocationFetcher 経由で一発取得
    private func useCurrentGPS() async {
        // 連打防止（MainActorでUIステート更新）
        await MainActor.run { isFetchingGPS = true }
        defer { Task { await MainActor.run { isFetchingGPS = false } } }

        // OneShot のコールバックを async/await にブリッジ
        let location: CLLocation? = await withCheckedContinuation { cont in
            oneShotFetcher.requestLocation { loc in
                cont.resume(returning: loc)
            }
        }

        // 結果反映（UI更新はMainActor）
        if let loc = location {
            await MainActor.run {
                // 既存の helper があるならそのまま
                apply(coord: loc.coordinate, animated: true)
            }
        } else {
            await MainActor.run {
                print("[GuideEditor] OneShot GPS failed")
                showingLocationAlert = true
            }
        }
    }

    @MainActor
    private func apply(coord: CLLocationCoordinate2D, animated: Bool) {
        selectedCoordinate = coord
        if animated {
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                ))
            }
        } else {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            ))
        }
    }
    
    // MARK: - Recording Methods
    
    private func startRecording() {
        Task {
            do {
                let success = try await recordingService.start()
                if !success {
                    showingPermissionAlert = true
                }
            } catch {
                print("Failed to start recording: \(error)")
                showingPermissionAlert = true
            }
        }
    }
    
    private func stopRecording() {
        tempRecordingURL = recordingService.stop()
    }
    
    private func cancelRecording() {
        recordingService.discard()
        tempRecordingURL = nil
    }
    
    private func reRecord() {
        if tempRecordingURL != nil {
            recordingService.discard()
            tempRecordingURL = nil
        }
        audioId = nil
        startRecording()
    }
    
    private func commitRecording() {
        guard tempRecordingURL != nil else { return }
        do {
            let newId = UUID()
            _ = try recordingService.commit(toPermanentWith: newId)
            audioId = "\(newId.uuidString).m4a"
            tempRecordingURL = nil
        } catch {
            print("Failed to commit recording: \(error)")
        }
    }
    
    // MARK: - Audio Preview
    
    private func startPreview(url: URL) {
        do {
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.delegate = previewDelegate
            previewDelegate.onFinish = {
                Task { @MainActor in
                    self.isPreviewing = false
                    self.previewPlayer = nil
                }
            }
            previewPlayer?.play()
            isPreviewing = true
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    private func previewCommittedAudio() {
        guard let audioId = audioId else { return }
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = documentsDir.appendingPathComponent("audio").appendingPathComponent(audioId)
        startPreview(url: audioURL)
    }
    
    private func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        isPreviewing = false
    }
    
    // MARK: - Save/Cancel
    
    private func handleSave() {
        guard isValidForSave else { return }
        
        let guide = GuidePoint(
            id: isNewMode ? UUID() : (mode.guide?.id ?? UUID()),
            latitude: selectedCoordinate.latitude,
            longitude: selectedCoordinate.longitude,
            radius: radius,
            message: label.trimmingCharacters(in: .whitespacesAndNewlines),
            audioId: audioId ?? ""
        )
        
        onSave(guide)
        dismiss()
    }
    
    private func handleCancel() {
        if tempRecordingURL != nil {
            recordingService.discard()
        }
        onCancel?()
        dismiss()
    }
    
    private func cleanupAudio() {
        stopPreview()
        if tempRecordingURL != nil {
            recordingService.discard()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension GuideEditorSheet.Mode {
    var guide: GuidePoint? {
        if case .edit(let guide) = self { return guide }
        return nil
    }
}

#Preview {
    GuideEditorSheet(
        mode: .new(initial: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503))
    ) { guide in
        print("Saved guide: \(guide)")
    } onDelete: { guide in
        print("Deleted guide: \(guide)")
    }
}


