import SwiftUI

struct RecordingView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Recording")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                
                Text("Voice guide recording will be implemented here")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Recording")
        }
    }
}

#Preview {
    RecordingView()
}