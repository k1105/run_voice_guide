import Foundation
import CoreLocation
import Combine
import UIKit

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()   // ← Singleton

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false

    private let locationManager = CLLocationManager()
    private var lastPublishedTime: Date = .distantPast
    private let updateInterval: TimeInterval = 5.0
    private let accuracyThreshold: CLLocationAccuracy = 50.0
    private let storageService = StorageService.shared

    // 背景保存の猶予確保（任意）
    private var bgTask: UIBackgroundTaskIdentifier = .invalid

    private override init() {
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone   // ← 時間スロットル主導
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermissions() {
        // Always を要求（OSの段階仕様により まずは WhenInUse が出ることあり）
        locationManager.requestAlwaysAuthorization()
    }

    func startTracking() {
        // WhenInUse でも動かす（要件は Always 推奨だが、記録欠落回避を優先）
        if authorizationStatus == .notDetermined {
            requestPermissions()
        }
        isTracking = true
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }

    private func shouldPublishLocation(_ location: CLLocation) -> Bool {
        let timeSinceLast = Date().timeIntervalSince(lastPublishedTime)
        let isAccurate = location.horizontalAccuracy > 0 && location.horizontalAccuracy <= accuracyThreshold
        let enoughTime = timeSinceLast >= updateInterval
        return isAccurate && enoughTime
    }

    private func beginBGTask() {
        guard bgTask == .invalid else { return }
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "LocationSave") { [weak self] in
            guard let self = self else { return }
            UIApplication.shared.endBackgroundTask(self.bgTask)
            self.bgTask = .invalid
        }
    }

    private func endBGTask() {
        guard bgTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let ts = DateFormatter.localizedString(from: location.timestamp, dateStyle: .none, timeStyle: .medium)
        print("[LocationUpdate] \(ts) lat=\(location.coordinate.latitude), lon=\(location.coordinate.longitude), acc=\(location.horizontalAccuracy)")

        if location.horizontalAccuracy > 50 {
            print("   → skipped (accuracy too low: \(location.horizontalAccuracy)m)")
            return
        }

        Task { @MainActor in
            // current を随時更新（UIの現在地ドット用）
            currentLocation = location

            // Run 未作成で Tracking 中かつ有効位置が来たら → 自動で Run を作成（開始点即保存）
            if isTracking, storageService.currentRun == nil {
                print("[LocationService] No currentRun. Creating one at first valid location.")
                storageService.startNewRun(at: location)  // この中で開始点TrackPointも保存する（後述）
            }

            // 5秒スロットルで確定ログ
            if shouldPublishLocation(location), let run = storageService.currentRun {
                lastPublishedTime = Date()
                beginBGTask()
                storageService.addTrackPoint(to: run, location: location)
                endBGTask()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            authorizationStatus = status
            if (status == .authorizedAlways || status == .authorizedWhenInUse), isTracking {
                locationManager.startUpdatingLocation()
            } else if status == .denied || status == .restricted {
                stopTracking()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}
