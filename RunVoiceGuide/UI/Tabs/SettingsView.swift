import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var importExportService = ImportExportService.shared
    
    @State private var showingExportPicker = false
    @State private var showingImportPicker = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("デフォルト半径")
                            Spacer()
                            Text("\(Int(settings.guideTriggerRadius))m")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Slider(
                            value: $settings.guideTriggerRadius,
                            in: 10...100,
                            step: 5
                        ) {
                            Text("New Guide Default Radius")
                        } minimumValueLabel: {
                            Text("10m")
                                .font(.caption)
                        } maximumValueLabel: {
                            Text("100m")
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("ガイドポイント初期値")
                } footer: {
                    Text("新しく作成するガイドポイントの初期トリガー半径。作成後は個別に調整可能です。")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Finish Radius")
                            Spacer()
                            Text("\(Int(settings.finishRadius))m")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Slider(
                            value: $settings.finishRadius,
                            in: 10...50,
                            step: 5
                        ) {
                            Text("Auto Finish Radius")
                        } minimumValueLabel: {
                            Text("10m")
                                .font(.caption)
                        } maximumValueLabel: {
                            Text("50m")
                                .font(.caption)
                        }
                    }
                    
                    Stepper(
                        "Consecutive Hits: \(settings.finishConsecutive)",
                        value: $settings.finishConsecutive,
                        in: 1...10
                    )
                } header: {
                    Text("自動終了設定")
                } footer: {
                    Text("自動終了には開始地点から\(Int(settings.finishRadius))m以内で\(settings.finishConsecutive)回連続の位置取得が必要")
                }
                
                Section {
                    Button("デフォルトに戻す") {
                        settings.resetToDefaults()
                    }
                    .foregroundColor(.orange)
                } header: {
                    Text("アクション")
                }
                
                Section {
                    Button("Export Audio & Guides") {
                        exportData()
                    }
                    .disabled(importExportService.isProcessing)
                    
                    Button("Import Audio & Guides") {
                        showingImportPicker = true
                    }
                    .disabled(importExportService.isProcessing)
                    
                    if importExportService.isProcessing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let error = importExportService.lastError {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .onTapGesture {
                                importExportService.clearLastError()
                            }
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Export creates a .rvgexport bundle with audio files and placement data. You can save to iCloud and import on other devices.")
                }
                
                Section {
                    HStack {
                        Text("ガイド初期半径")
                        Spacer()
                        Text("\(Int(settings.guideTriggerRadius))m")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("終了判定半径")
                        Spacer()
                        Text("\(Int(settings.finishRadius))m")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("終了判定回数")
                        Spacer()
                        Text("\(settings.finishConsecutive)")
                            .font(.system(.body, design: .monospaced))
                    }
                } header: {
                    Text("現在の設定値")
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingExportPicker) {
            if let url = exportURL {
                DocumentPicker(url: url, mode: .export)
            }
        }
        .sheet(isPresented: $showingImportPicker) {
            DocumentPicker(mode: .import) { url in
                importData(from: url)
            }
        }
    }
    
    private func exportData() {
        Task {
            do {
                let exportURL = try await importExportService.exportAudioAndPlacement()
                await MainActor.run {
                    self.exportURL = exportURL
                    showingExportPicker = true
                }
            } catch {
                await MainActor.run {
                    importExportService.lastError = error.localizedDescription
                }
            }
        }
    }
    
    private func importData(from url: URL) {
        Task {
            do {
                try await importExportService.importAudioAndPlacement(from: url)
            } catch {
                await MainActor.run {
                    importExportService.lastError = error.localizedDescription
                }
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let url: URL?
    let mode: Mode
    let onImport: ((URL) -> Void)?
    
    enum Mode {
        case export
        case `import`
    }
    
    init(url: URL, mode: Mode) {
        self.url = url
        self.mode = mode
        self.onImport = nil
    }
    
    init(mode: Mode, onImport: @escaping (URL) -> Void) {
        self.url = nil
        self.mode = mode
        self.onImport = onImport
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        switch mode {
        case .export:
            guard let url = url else {
                fatalError("Export mode requires URL")
            }
            let picker = UIDocumentPickerViewController(forExporting: [url])
            return picker
            
        case .import:
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item])
            picker.delegate = context.coordinator
            return picker
        }
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onImport?(url)
        }
    }
}

#Preview {
    SettingsView()
}