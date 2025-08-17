import SwiftUI
import MapKit
import CoreLocation

public struct TrackMapView: View {
    let track: [CLLocationCoordinate2D]
    let guides: [GuidePin]
    let start: CLLocationCoordinate2D?
    let endRadius: CLLocationDistance?
    let current: CLLocationCoordinate2D?
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapSelection: String?
    
    public init(
        track: [CLLocationCoordinate2D],
        guides: [GuidePin],
        start: CLLocationCoordinate2D? = nil,
        endRadius: CLLocationDistance? = nil,
        current: CLLocationCoordinate2D? = nil
    ) {
        self.track = track
        self.guides = guides
        self.start = start
        self.endRadius = endRadius
        self.current = current
    }
    
    public var body: some View {
        mapView
    }
    
    private var mapView: some View {
        MapReader { reader in
            Map(position: $cameraPosition, selection: $mapSelection) {
                trackPolyline
                guidePins
                startLocationPin
                endRadiusCircle
                currentLocationDot
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.publicTransport])))
            .mapControls {
                MapCompass()
                MapPitchToggle()
                MapUserLocationButton()
            }
            .onAppear {
                updateCameraPosition()
            }
        }
    }
    
    @MapContentBuilder
    private var trackPolyline: some MapContent {
        if !track.isEmpty {
            MapPolyline(coordinates: track)
                .stroke(.blue.opacity(0.7), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
    }
    
    @MapContentBuilder
    private var guidePins: some MapContent {
        ForEach(guides) { guide in
            Annotation(
                guide.label ?? "Guide",
                coordinate: guide.coord,
                anchor: .bottom
            ) {
                guidePinView(for: guide)
            }
            .tag(guide.id)
        }
    }
    
    private func guidePinView(for guide: GuidePin) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundColor(guide.hasAudio ? .red : .orange)
                .background(Color.white.clipShape(Circle()))
            
            if let label = guide.label {
                Text(label)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(4)
                    .shadow(radius: 1)
            }
        }
    }
    
    @MapContentBuilder
    private var startLocationPin: some MapContent {
        if let startCoord = start {
            Annotation("Start", coordinate: startCoord, anchor: .bottom) {
                startPinView
            }
            .tag("start")
        }
    }
    
    private var startPinView: some View {
        VStack(spacing: 0) {
            Image(systemName: "flag.circle.fill")
                .font(.title)
                .foregroundColor(.green)
                .background(Color.white.clipShape(Circle()))
            
            Text("Start")
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.9))
                .cornerRadius(4)
                .shadow(radius: 1)
        }
    }
    
    @MapContentBuilder
    private var endRadiusCircle: some MapContent {
        if let startCoord = start, let radius = endRadius {
            MapCircle(center: startCoord, radius: radius)
                .foregroundStyle(.green.opacity(0.15))
                .stroke(.green.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
        }
    }
    
    @MapContentBuilder
    private var currentLocationDot: some MapContent {
        if let currentCoord = current {
            Annotation("Current", coordinate: currentCoord, anchor: .center) {
                currentLocationView
            }
            .tag("current")
        }
    }
    
    private var currentLocationView: some View {
        Circle()
            .fill(.cyan)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: 3)
            )
            .shadow(radius: 2)
    }
    
    private func updateCameraPosition() {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Add track coordinates
        coordinates.append(contentsOf: track)
        
        // Add guide coordinates
        coordinates.append(contentsOf: guides.map { $0.coord })
        
        // Add start coordinate
        if let start = start {
            coordinates.append(start)
        }
        
        // Add current coordinate
        if let current = current {
            coordinates.append(current)
        }
        
        guard !coordinates.isEmpty else {
            cameraPosition = .automatic
            return
        }
        
        if coordinates.count == 1 {
            // Single point - center on it with reasonable zoom
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinates[0],
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            ))
        } else {
            // Multiple points - fit them all with padding
            let minLat = coordinates.map { $0.latitude }.min() ?? 0
            let maxLat = coordinates.map { $0.latitude }.max() ?? 0
            let minLng = coordinates.map { $0.longitude }.min() ?? 0
            let maxLng = coordinates.map { $0.longitude }.max() ?? 0
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.2, 0.001),
                longitudeDelta: max((maxLng - minLng) * 1.2, 0.001)
            )
            
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}

extension TrackMapView {
    public struct GuidePin: Identifiable {
        public let id: String
        public let coord: CLLocationCoordinate2D
        public let hasAudio: Bool
        public let label: String?
        
        public init(id: String, coord: CLLocationCoordinate2D, hasAudio: Bool, label: String? = nil) {
            self.id = id
            self.coord = coord
            self.hasAudio = hasAudio
            self.label = label
        }
    }
}

#Preview {
    // Sample track coordinates (a small loop in Tokyo)
    let sampleTrack = [
        CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        CLLocationCoordinate2D(latitude: 35.6765, longitude: 139.6506),
        CLLocationCoordinate2D(latitude: 35.6768, longitude: 139.6509),
        CLLocationCoordinate2D(latitude: 35.6771, longitude: 139.6512),
        CLLocationCoordinate2D(latitude: 35.6768, longitude: 139.6515),
        CLLocationCoordinate2D(latitude: 35.6765, longitude: 139.6512),
        CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6509),
        CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
    ]
    
    // Sample guide pins
    let sampleGuides = [
        TrackMapView.GuidePin(id: "1", coord: CLLocationCoordinate2D(latitude: 35.6765, longitude: 139.6506), hasAudio: true, label: "Checkpoint 1"),
        TrackMapView.GuidePin(id: "2", coord: CLLocationCoordinate2D(latitude: 35.6768, longitude: 139.6509), hasAudio: false, label: "Checkpoint 2"),
        TrackMapView.GuidePin(id: "3", coord: CLLocationCoordinate2D(latitude: 35.6771, longitude: 139.6512), hasAudio: true, label: "Finish")
    ]
    
    TrackMapView(
        track: sampleTrack,
        guides: sampleGuides,
        start: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        endRadius: 30.0,
        current: CLLocationCoordinate2D(latitude: 35.6768, longitude: 139.6509)
    )
}
