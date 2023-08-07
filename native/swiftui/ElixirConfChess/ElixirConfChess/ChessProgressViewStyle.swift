//
//  ChessProgressViewStyle.swift
//  ElixirConfChess
//
//  Created by Carson Katri on 8/3/23.
//

import SwiftUI

struct ChessProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ChessSquare(fill: .evenBackground) {}
                    ChessSquare(fill: .oddBackground) {}
                    ChessSquare(fill: .evenBackground) {}
                }
                GridRow {
                    ChessSquare(fill: .oddBackground) {}
                    ChessSquare(fill: .evenBackground) {}
                    ChessSquare(fill: .oddBackground) {}
                }
                GridRow {
                    ChessSquare(fill: .evenBackground) {}
                    ChessSquare(fill: .oddBackground) {}
                    ChessSquare(fill: .evenBackground) {}
                }
            }
            .overlay {
                TimelineView(.animation) { timeline in
                    Text("♜")
                        .offset(
                            x: sin(timeline.date.timeIntervalSince1970) * 75,
                            y: 0
                        )
                }
                .foregroundStyle(.white)
                .font(.system(size: 80))
                .baselineOffset(15)
                .frame(width: 75, height: 75)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.bottom)
            configuration.label
                .font(.title.bold())
        }
        .padding()
    }
}
            
extension ProgressViewStyle where Self == ChessProgressViewStyle {
    static var chess: ChessProgressViewStyle { .init() }
}
