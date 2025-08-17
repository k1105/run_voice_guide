import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Settings")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                
                Text("App settings will be configured here")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}