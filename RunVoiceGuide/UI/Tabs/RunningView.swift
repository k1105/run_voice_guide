import SwiftUI
import CoreLocation

struct RunningView: View {
    @StateObject private var locationService = LocationService()
    @StateObject private var storageService = StorageService.shared
    @StateObject private var geofenceService = GeofenceService()
    @StateObject private var audioService = AudioService()
    
    @State private var currentCourse: Course?
    @State private var autoFinishJudge: AutoFinishJudge?
    @State private var showCompletionBanner = false
    @State private var trackCoordinates: [CLLocationCoordinate2D] = []
    
    // MARK: - Computed Properties for TrackMapView
    
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
    
    private var startLocation: CLLocationCoordinate2D? {
        guard let course = currentCourse,
              let firstGuide = course.guidePoints.first else { return nil }
        
        return CLLocationCoordinate2D(
            latitude: firstGuide.latitude,
            longitude: firstGuide.longitude
        )
    }
    
    private var endRadius: CLLocationDistance? {
        // Use the same radius as AutoFinishJudge (30.0 meters)
        return autoFinishJudge != nil ? 30.0 : nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // スクロール可能に
                ScrollView {
                    VStack(spacing: 20) {
                        TrackMapView(
                            track: trackCoordinates,
                            guides: mappedGuides,
                            start: startLocation,
                            endRadius: endRadius,
                            current: locationService.currentLocation?.coordinate
                        )
                        .frame(height: 360)
                        .cornerRadius(12)
                        
                        VStack(spacing: 16) {
                            // Current Run Status
                            if let currentRun = storageService.currentRun {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Current Run:")
                                        .font(.headline)
                                    
                                    Text("Started: \(currentRun.startedAt ?? Date(), formatter: timeFormatter)")
                                        .font(.caption)
                                    
                                    Text("Start Location: \(currentRun.startLat, specifier: "%.6f"), \(currentRun.startLng, specifier: "%.6f")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("ID: \(currentRun.id?.uuidString.prefix(8) ?? "unknown")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if let judge = autoFinishJudge, locationService.isTracking {
                                        Divider()
                                        
                                        HStack {
                                            Image(systemName: "flag.checkered")
                                                .foregroundColor(.orange)
                                            Text("Auto-finish: \(judge.consecutiveHits)/3 hits")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                        
                                        if judge.shouldFinish {
                                            HStack {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                                Text("Ready to finish!")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                            
                            if let location = locationService.currentLocation {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Current Location:")
                                        .font(.headline)
                                    
                                    Text("Latitude: \(location.coordinate.latitude, specifier: "%.6f")")
                                        .font(.monospaced(.body)())
                                    
                                    Text("Longitude: \(location.coordinate.longitude, specifier: "%.6f")")
                                        .font(.monospaced(.body)())
                                    
                                    Text("Accuracy: \(location.horizontalAccuracy, specifier: "%.1f")m")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Updated: \(Date(), formatter: timeFormatter)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            } else {
                                Text("No location data")
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                            
                            // Course and Audio Status
                            if let course = currentCourse {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Course: \(course.name)")
                                        .font(.headline)
                                    
                                    Text("\(course.guidePoints.count) guide points")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if audioService.isPlaying {
                                        HStack {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .foregroundColor(.green)
                                            Text("Playing: \(audioService.currentAudioId ?? "unknown")")
                                                .font(.caption)
                                        }
                                    }
                                    
                                    Text("Triggered: \(geofenceService.getTriggeredIds().count) points")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    
                                    Text("Track: \(trackCoordinates.count) coordinates")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                    
                                    // Test button to simulate being near first guide point
                                    Button("Test Audio (Simulate Guide Point)") {
                                        if let firstGuidePoint = course.guidePoints.first {
                                            print("[Test] Simulating guide point hit: \(firstGuidePoint.message)")
                                            audioService.play(audioId: firstGuidePoint.audioId)
                                        }
                                    }
                                    .font(.caption)
                                    .padding(.top, 4)
                                    
                                    // Test button to simulate auto-finish
                                    if let judge = autoFinishJudge, locationService.isTracking {
                                        Button("Test Auto-Finish (Simulate Start Location)") {
                                            print("[Test] Simulating location at start for auto-finish")
                                            let startLocation = judge.startLocation
                                            // Simulate 3 consecutive hits at start location
                                            for i in 1...3 {
                                                judge.processLocationUpdate(startLocation)
                                                print("[Test] Simulated hit \(i)/3")
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.top, 2)
                                    }
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                            }
                            
                            authorizationStatusView
                        }
                        .padding(.bottom, 80) // ボタン領域分の余白
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                // Completion Banner
                if showCompletionBanner {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading) {
                                Text("Run Completed!")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                
                                Text("Auto-finished at start location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Dismiss") {
                                showCompletionBanner = false
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                    .padding()
                    .transition(.move(edge: .top))
                    .animation(.easeInOut, value: showCompletionBanner)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 16) {
                    Button(action: {
                        if locationService.isTracking {
                            // Stop tracking and finish current run
                            locationService.stopTracking()
                            storageService.finishCurrentRun()
                            audioService.stop()
                            audioService.deactivateSession()
                            geofenceService.reset()
                            autoFinishJudge?.reset()
                            autoFinishJudge = nil
                        } else {
                            // Start tracking and create new run if needed
                            audioService.activateSession()
                            
                            trackCoordinates.removeAll()
                            
                            guard let location = locationService.currentLocation else {
                                locationService.startTracking()
                                return
                            }
                            
                            if storageService.currentRun == nil {
                                storageService.startNewRun(at: location)
                            }
                            
                            autoFinishJudge = AutoFinishJudge(
                                startLatitude: location.coordinate.latitude,
                                startLongitude: location.coordinate.longitude,
                                endRadius: 30.0,
                                requiredConsecutiveHits: 3
                            )
                            
                            locationService.startTracking()
                        }
                    }) {
                        HStack {
                            Image(systemName: locationService.isTracking ? "stop.circle.fill" : "play.circle.fill")
                            Text(locationService.isTracking ? "Stop Run" : "Start Run")
                        }
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(locationService.isTracking ? Color.red : Color.green)
                        .cornerRadius(10)
                    }
                    .disabled(locationService.authorizationStatus != .authorizedAlways)
                    
                    if storageService.currentRun != nil && !locationService.isTracking {
                        Button(action: {
                            storageService.finishCurrentRun()
                            autoFinishJudge?.reset()
                            autoFinishJudge = nil
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Finish Run")
                            }
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .navigationTitle("Running")
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onAppear {
                if locationService.authorizationStatus == .notDetermined {
                    locationService.requestPermissions()
                }
                
                if currentCourse == nil {
                    currentCourse = CourseLoader.loadDefaultCourse()
                }
                
                if storageService.currentRun != nil &&
                   locationService.authorizationStatus == .authorizedAlways &&
                   !locationService.isTracking {
                    audioService.activateSession()
                    locationService.startTracking()
                }
            }
            .onChange(of: locationService.currentLocation) { newLocation in
                if let location = newLocation, locationService.isTracking {
                    trackCoordinates.append(location.coordinate)
                    print("[RunningView] Added coordinate to track: \(location.coordinate.latitude), \(location.coordinate.longitude) (total: \(trackCoordinates.count))")
                }
                
                guard let location = newLocation,
                      locationService.isTracking else { return }
                
                if let course = currentCourse {
                    let hits = geofenceService.checkHits(at: location, guidePoints: course.guidePoints)
                    
                    for hit in hits {
                        print("[RunningView] Guide point hit: \(hit.message)")
                        audioService.play(audioId: hit.audioId)
                    }
                }
                
                if let judge = autoFinishJudge {
                    judge.processLocationUpdate(location)
                    
                    if judge.shouldFinish {
                        print("[RunningView] Auto-finishing run!")
                        
                        locationService.stopTracking()
                        storageService.finishCurrentRun(endRadius: 30.0, finishConsecutive: Int32(judge.consecutiveHits))
                        audioService.stop()
                        audioService.deactivateSession()
                        geofenceService.reset()
                        
                        showCompletionBanner = true
                        
                        autoFinishJudge?.reset()
                        autoFinishJudge = nil
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var authorizationStatusView: some View {
        HStack {
            Image(systemName: authorizationIcon)
                .foregroundColor(authorizationColor)
            Text(authorizationText)
                .font(.caption)
                .foregroundColor(authorizationColor)
        }
        .padding(.horizontal)
    }
    
    private var authorizationIcon: String {
        switch locationService.authorizationStatus {
        case .authorizedAlways:
            return "checkmark.circle.fill"
        case .authorizedWhenInUse:
            return "exclamationmark.triangle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }
    
    private var authorizationColor: Color {
        switch locationService.authorizationStatus {
        case .authorizedAlways:
            return .green
        case .authorizedWhenInUse:
            return .orange
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .blue
        @unknown default:
            return .gray
        }
    }
    
    private var authorizationText: String {
        switch locationService.authorizationStatus {
        case .authorizedAlways:
            return "Location Always Authorized"
        case .authorizedWhenInUse:
            return "Location When In Use Only - Need Always Authorization"
        case .denied:
            return "Location Access Denied"
        case .restricted:
            return "Location Access Restricted"
        case .notDetermined:
            return "Location Authorization Pending"
        @unknown default:
            return "Unknown Authorization Status"
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
}

#Preview {
    RunningView()
}
