import SwiftUI
import CoreLocation

struct RunningView: View {
    @StateObject private var locationService = LocationService.shared   // ← shared を使う
    @StateObject private var storageService = StorageService.shared
    @StateObject private var geofenceService = GeofenceService()
    @StateObject private var audioService = AudioService()
    @StateObject private var settings = SettingsStore.shared

    @State private var currentCourse: Course?
    @State private var guidePoints: [GuidePoint] = []
    @State private var autoFinishJudge: AutoFinishJudge?
    @State private var showCompletionBanner = false
    @State private var trackCoordinates: [CLLocationCoordinate2D] = []

    // MARK: - Map bindings

    private var mappedGuides: [TrackMapView.GuidePin] {
        return guidePoints.map { gp in
            TrackMapView.GuidePin(
                id: gp.id.uuidString,
                coord: .init(latitude: gp.latitude, longitude: gp.longitude),
                hasAudio: !gp.audioId.isEmpty,
                label: gp.message.isEmpty ? nil : gp.message
            )
        }
    }

    private var startLocation: CLLocationCoordinate2D? {
        // 便宜上：先頭ガイド位置を start の見た目に
        guard let first = guidePoints.first else { return nil }
        return .init(latitude: first.latitude, longitude: first.longitude)
    }

    private var endRadius: CLLocationDistance? {
        autoFinishJudge != nil ? settings.finishRadius : nil
    }

    var body: some View {
        NavigationView {
            ZStack {
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
                                    Text("Current Run:").font(.headline)

                                    Text("Started: \(currentRun.startedAt ?? Date(), formatter: timeFormatter)")
                                        .font(.caption)

                                    Text("Start Location: \(currentRun.startLat, specifier: "%.6f"), \(currentRun.startLng, specifier: "%.6f")")
                                        .font(.caption).foregroundColor(.secondary)

                                    Text("ID: \(currentRun.id?.uuidString.prefix(8) ?? "unknown")")
                                        .font(.caption).foregroundColor(.secondary)

                                    if let judge = autoFinishJudge, locationService.isTracking {
                                        Divider()
                                        HStack {
                                            Image(systemName: "flag.checkered").foregroundColor(.orange)
                                            Text("Auto-finish: \(judge.consecutiveHits)/3 hits")
                                                .font(.caption).foregroundColor(.orange)
                                        }
                                        if judge.shouldFinish {
                                            HStack {
                                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                                Text("Ready to finish!")
                                                    .font(.caption).foregroundColor(.green).fontWeight(.semibold)
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
                                    Text("Current Location:").font(.headline)
                                    Text("Latitude: \(location.coordinate.latitude, specifier: "%.6f")").font(.monospaced(.body)())
                                    Text("Longitude: \(location.coordinate.longitude, specifier: "%.6f")").font(.monospaced(.body)())
                                    Text("Accuracy: \(location.horizontalAccuracy, specifier: "%.1f")m").font(.caption).foregroundColor(.secondary)
                                    Text("Updated: \(Date(), formatter: timeFormatter)").font(.caption).foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            } else {
                                Text("No location data").foregroundColor(.secondary).padding()
                            }

                            // Guide Points & Audio status
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Guide Points").font(.headline)
                                Text("\(guidePoints.count) guide points").font(.caption).foregroundColor(.secondary)

                                    if audioService.isPlaying {
                                        HStack {
                                            Image(systemName: "speaker.wave.2.fill").foregroundColor(.green)
                                            Text("Playing: \(audioService.currentAudioId ?? "unknown")").font(.caption)
                                        }
                                    }
                                    
                                    if audioService.isBGMPlaying {
                                        HStack {
                                            Image(systemName: "music.note").foregroundColor(.blue)
                                            Text("BGM Playing").font(.caption).foregroundColor(.blue)
                                        }
                                    }

                                    Text("Triggered: \(geofenceService.getTriggeredIds().count) points")
                                        .font(.caption).foregroundColor(.blue)
                                Text("Track: \(trackCoordinates.count) coordinates")
                                    .font(.caption).foregroundColor(.purple)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)

                            authorizationStatusView
                        }
                        .padding(.bottom, 80) // 下部固定ボタン領域の逃し
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }

                // 完了バナー
                if showCompletionBanner {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").font(.title).foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Run Completed!").font(.headline).foregroundColor(.green)
                                Text("Auto-finished at start location").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Dismiss") { showCompletionBanner = false }
                                .font(.caption)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3), lineWidth: 1))
                    .padding()
                    .transition(.move(edge: .top))
                    .animation(.easeInOut, value: showCompletionBanner)
                }
            }
            // 下部固定ボタン（背景は透明のまま）
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 16) {
                                            Button {
                            if locationService.isTracking {
                                // Stop & finish
                                locationService.stopTracking()
                                storageService.finishCurrentRun()
                                audioService.stop()
                                audioService.stopBGM()
                                audioService.deactivateSession()
                                geofenceService.reset()
                                autoFinishJudge?.reset(); autoFinishJudge = nil
                            } else {
                                // Start
                                audioService.activateSession()
                                trackCoordinates.removeAll()

                                // 位置が無い場合でも startTracking。最初の有効位置で自動Run開始（LocationService側で対応）
                                locationService.startTracking()

                                // もし現時点で位置があれば、直ちに Run 作成＋AutoFinishJudge
                                if let loc = locationService.currentLocation {
                                    if storageService.currentRun == nil {
                                        storageService.startNewRun(at: loc)
                                    }
                                    autoFinishJudge = AutoFinishJudge(
                                        startLatitude: loc.coordinate.latitude,
                                        startLongitude: loc.coordinate.longitude,
                                        endRadius: settings.finishRadius,
                                        requiredConsecutiveHits: settings.finishConsecutive
                                    )
                                }
                                
                                // Start BGM if enabled
                                if settings.bgmEnabled {
                                    audioService.startBGM()
                                }
                            }
                        } label: {
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
                    // Always推奨だが、WhenInUseでも動かす方針に変更したため disable はやめる
                    // .disabled(locationService.authorizationStatus != .authorizedAlways)

                    if storageService.currentRun != nil && !locationService.isTracking {
                        Button {
                            storageService.finishCurrentRun()
                            audioService.stopBGM()
                            autoFinishJudge?.reset(); autoFinishJudge = nil
                        } label: {
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
                
                // Load persisted guide points
                loadGuidePoints()
                
                // Subscribe to guide points changes
                NotificationCenter.default.addObserver(
                    forName: .guidePointsDidChange,
                    object: nil,
                    queue: .main
                ) { _ in
                    loadGuidePoints()
                    geofenceService.reset()
                }
                
                // 未終了Runがあり権限OKなら再開
                if storageService.currentRun != nil &&
                    (locationService.authorizationStatus == .authorizedAlways ||
                     locationService.authorizationStatus == .authorizedWhenInUse) &&
                    !locationService.isTracking {
                    audioService.activateSession()
                    locationService.startTracking()
                    if settings.bgmEnabled {
                        audioService.startBGM()
                    }
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: .guidePointsDidChange, object: nil)
            }
            .onChange(of: locationService.currentLocation) { newLocation in
                guard let location = newLocation else { return }

                // UI上の軌跡は毎回伸ばす（5秒スロットルでなくても可視性重視）
                if locationService.isTracking {
                    trackCoordinates.append(location.coordinate)
                    print("[RunningView] track += (\(location.coordinate.latitude), \(location.coordinate.longitude)) total=\(trackCoordinates.count)")
                }

                guard locationService.isTracking else { return }

                // ガイド到達 & 再生
                let hits = geofenceService.checkHits(at: location, guidePoints: guidePoints)
                for hit in hits {
                    print("[RunningView] Guide hit: \(hit.message)")
                    if !hit.audioId.isEmpty {
                        audioService.playGuideWithNotation(audioId: hit.audioId)
                    }
                }

                // 自動終了
                if let judge = autoFinishJudge {
                    judge.processLocationUpdate(location)
                    if judge.shouldFinish {
                        print("[RunningView] Auto-finishing run!")
                        locationService.stopTracking()
                        storageService.finishCurrentRun(endRadius: settings.finishRadius, finishConsecutive: Int32(judge.consecutiveHits))
                        audioService.stop(); audioService.stopBGM(); audioService.deactivateSession()
                        geofenceService.reset()
                        showCompletionBanner = true
                        autoFinishJudge?.reset(); autoFinishJudge = nil
                    }
                } else {
                    // AutoFinishJudge が未設定で、Run があって現在地があるなら初期化（Start直後位置無しだったケースの救済）
                    if let run = storageService.currentRun {
                        autoFinishJudge = AutoFinishJudge(
                            startLatitude: run.startLat,
                            startLongitude: run.startLng,
                            endRadius: settings.finishRadius,
                            requiredConsecutiveHits: settings.finishConsecutive
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Guide Points Management
    
    private func loadGuidePoints() {
        guidePoints = CourseLoader.loadGuidePoints()
        print("[RunningView] Loaded \(guidePoints.count) guide points")
    }

    // MARK: - Aux UI

    @ViewBuilder
    private var authorizationStatusView: some View {
        HStack {
            Image(systemName: authorizationIcon).foregroundColor(authorizationColor)
            Text(authorizationText).font(.caption).foregroundColor(authorizationColor)
        }
        .padding(.horizontal)
    }

    private var authorizationIcon: String {
        switch locationService.authorizationStatus {
        case .authorizedAlways: return "checkmark.circle.fill"
        case .authorizedWhenInUse: return "exclamationmark.triangle.fill"
        case .denied, .restricted: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        @unknown default: return "questionmark.circle.fill"
        }
    }

    private var authorizationColor: Color {
        switch locationService.authorizationStatus {
        case .authorizedAlways: return .green
        case .authorizedWhenInUse: return .orange
        case .denied, .restricted: return .red
        case .notDetermined: return .blue
        @unknown default: return .gray
        }
    }

    private var authorizationText: String {
        switch locationService.authorizationStatus {
        case .authorizedAlways: return "Location Always Authorized"
        case .authorizedWhenInUse: return "When In Use - Consider Always for BG"
        case .denied: return "Location Access Denied"
        case .restricted: return "Location Access Restricted"
        case .notDetermined: return "Location Authorization Pending"
        @unknown default: return "Unknown Authorization Status"
        }
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f
    }
}

#Preview { RunningView() }
