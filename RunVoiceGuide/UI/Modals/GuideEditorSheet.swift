import SwiftUI

struct GuideEditorSheet: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Guide Editor")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                
                Text("Guide editing functionality will be implemented here")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Edit Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    GuideEditorSheet(isPresented: .constant(true))
}