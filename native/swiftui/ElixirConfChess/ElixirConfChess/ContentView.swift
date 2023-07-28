//
//  ContentView.swift
//  ElixirConfChess
//
//  Created by Carson.Katri on 7/27/23.
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
