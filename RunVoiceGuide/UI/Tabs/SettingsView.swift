import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    
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
    }
}

#Preview {
    SettingsView()
}