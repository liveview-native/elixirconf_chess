//
//  ConnectionErrorView.swift
//  ElixirConfChess
//
//  Created by Carson Katri on 8/3/23.
//

import SwiftUI

struct ChessSquare<Content: View>: View {
    let fill: Color
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ZStack {
            Group {
                Rectangle()
                    .fill(fill)
                content()
                    .font(.system(size: 80))
                    .baselineOffset(15)
                    .frame(width: 75, height: 75)
            }
            .frame(width: 75, height: 75, alignment: .bottom)
        }
    }
}

struct ConnectionErrorView: View {
    let error: Error
    
    var body: some View {
        VStack {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ChessSquare(fill: .evenBackground) {}
                    ChessSquare(fill: .oddBackground) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 45))
                            .foregroundStyle(.white)
                    }
                    ChessSquare(fill: .evenBackground) {}
                }
                GridRow {
                    ChessSquare(fill: .oddBackground) {}
                    ChessSquare(fill: .evenBackground) {
                        Text("♛")
                            .foregroundStyle(.black)
                    }
                    ChessSquare(fill: .oddBackground) {}
                }
                GridRow {
                    ChessSquare(fill: .evenBackground) {
                        Text("♚")
                            .foregroundStyle(.black)
                    }
                    ChessSquare(fill: .oddBackground) {}
                    ChessSquare(fill: .evenBackground) {}
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.bottom)
            Text("Checkmate")
                .font(.title.bold())
            Text(
                    """
                    An error occurred while loading the app.
                    Please check your internet connection.
                    """
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
    }
}

extension Color {
    static var evenBackground: Color {
        .init(red: 1, green: 0.8, blue: 0.62)
    }
    static var oddBackground: Color {
        .init(red: 0.82, green: 0.54, blue: 0.28)
    }
}
