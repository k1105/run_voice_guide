import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    
    private let locationManager = CLLocationManager()
    private var lastPublishedTime: Date = Date.distantPast
    private let updateInterval: TimeInterval = 5.0
    private let accuracyThreshold: CLLocationAccuracy = 50.0
    private let storageService = StorageService.shared
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermissions() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startTracking() {
        guard authorizationStatus == .authorizedAlways else {
            requestPermissions()
            return
        }
        
        isTracking = true
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }
    
    private func shouldPublishLocation(_ location: CLLocation) -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastPublishedTime)
        let isAccurateEnough = location.horizontalAccuracy <= accuracyThreshold && location.horizontalAccuracy > 0
        let hasEnoughTimePassed = timeSinceLastUpdate >= updateInterval
        
        return isAccurateEnough && hasEnoughTimePassed
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let ts = DateFormatter.localizedString(from: location.timestamp, dateStyle: .none, timeStyle: .medium)
        print("[LocationUpdate] \(ts) lat=\(location.coordinate.latitude), lon=\(location.coordinate.longitude), acc=\(location.horizontalAccuracy)")

        // 精度フィルタ
        if location.horizontalAccuracy > 50 {
            print("   → skipped (accuracy too low: \(location.horizontalAccuracy)m)")
            return
        }

        
        Task { @MainActor in
            if shouldPublishLocation(location) {
                currentLocation = location
                lastPublishedTime = Date()
                
                // Save track point if we have an active run
                if let currentRun = storageService.currentRun {
                    storageService.addTrackPoint(to: currentRun, location: location)
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            authorizationStatus = status
            
            if status == .authorizedAlways && isTracking {
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
