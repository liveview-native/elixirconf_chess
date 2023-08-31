//
//  ContentView.swift
//  ElixirConfChess
//
//  Created by Carson Katri on 7/27/23.
//

import SwiftUI
import LiveViewNative

struct ContentView: View {
    var body: some View {
        LiveView<ChessRegistry>(.automatic(URL(string: "https://chess.dockyard.com/")!), configuration: .init(navigationMode: .enabled))
            #if os(macOS)
            .frame(idealWidth: 500, idealHeight: 700)
            #endif
    }
}

enum ChessRegistry: RootRegistry {
    enum TagName: String {
        case openGameListener = "OpenGameListener"
    }
    
    private struct OpenGameListener: View {
        @LiveContext<ChessRegistry> private var context
        
        var body: some View {
            EmptyView()
                .onOpenURL { url in
                    guard let game = url.host() else { return }
                    Task {
                        try await context.coordinator.pushEvent(type: "click", event: "join", value: ["id": game])
                    }
                }
        }
    }
    
    static func lookup(_ name: TagName, element: ElementNode) -> some View {
        switch name {
        case .openGameListener:
            OpenGameListener()
        }
    }
    
    static func loadingView(for url: URL, state: LiveSessionState) -> some View {
        switch state {
        case .connectionFailed(let error):
            ConnectionErrorView(error: error)
        default:
            ProgressView("Loading...")
                .progressViewStyle(.chess)
                .transition(.opacity)
        }
    }
    
    static func errorView(for error: Error) -> some View {
        ProgressView()
    }
}
