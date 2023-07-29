//
//  ContentView.swift
//  ElixirConfChessWatch Watch App
//
//  Created by Carson.Katri on 7/28/23.
//

import SwiftUI
import LiveViewNative

struct ContentView: View {
    var body: some View {
        LiveView(.localhost)
    }
}

#Preview {
    ContentView()
}
