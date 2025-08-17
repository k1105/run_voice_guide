import SwiftUI
import MapKit
import CoreLocation

struct GuideEditorSheet: View {
    let initial: CLLocationCoordinate2D
    let onCommit: (CLLocationCoordinate2D, CLLocationDistance) -> Void
    
    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var radius: CLLocationDistance
    @State private var cameraPosition: MapCameraPosition
    @Environment(\.dismiss) private var dismiss
    
    init(initial: CLLocationCoordinate2D, radius: CLLocationDistance = 40, onCommit: @escaping (CLLocationCoordinate2D, CLLocationDistance) -> Void) {
        self.initial = initial
        self.onCommit = onCommit
        self._selectedCoordinate = State(initialValue: initial)
        self._radius = State(initialValue: radius)
        self._cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: initial,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                mapView
                
                controlsView
            }
            .navigationTitle("Edit Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onCommit(selectedCoordinate, radius)
                        dismiss()
                    }
                }
            }
        }
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
        .frame(minHeight: 300)
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
    
    private var controlsView: some View {
        VStack(spacing: 16) {
            Button("Use Current GPS") {
                if let currentLocation = LocationService.shared.currentLocation {
                    selectedCoordinate = currentLocation.coordinate
                    withAnimation(.easeInOut(duration: 0.5)) {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: currentLocation.coordinate,
                            latitudinalMeters: 1000,
                            longitudinalMeters: 1000
                        ))
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(LocationService.shared.currentLocation == nil)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Coordinates")
                    .font(.headline)
                
                Text("Lat: \(selectedCoordinate.latitude, specifier: "%.6f")")
                    .font(.system(.body, design: .monospaced))
                
                Text("Lng: \(selectedCoordinate.longitude, specifier: "%.6f")")
                    .font(.system(.body, design: .monospaced))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Radius: \(Int(radius))m")
                    .font(.headline)
                
                Slider(value: $radius, in: 10...100, step: 5) {
                    Text("Radius")
                } minimumValueLabel: {
                    Text("10m")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("100m")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    GuideEditorSheet(
        initial: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        radius: 40
    ) { coordinate, radius in
        print("Saved: \(coordinate), radius: \(radius)")
    }
}