//
//  ContentView.swift
//  RunVoiceGuide
//
//  Created by Kanata Yamagishi on 2025/08/17.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RunningView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("Running")
                }
            
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
            
            RecordingView()
                .tabItem {
                    Image(systemName: "waveform")
                    Text("Recording")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

#Preview {
    ContentView()
}
