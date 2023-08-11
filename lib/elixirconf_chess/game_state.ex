defmodule ElixirconfChess.GameState do
  defstruct board: ElixirconfChess.GameBoard.start_board(),
            turn: :white,
            spectators: [],
            white: nil,
            black: nil,
            white_is_ai: false,
            black_is_ai: false,
            state: :active,
            move_history: []

  def description(%{state: :active, turn: turn}), do: "#{turn |> Atom.to_string() |> String.capitalize()}'s Turn"
  def description(%{state: :draw}), do: "Draw"
  def description(%{state: {:checkmate, loser}}), do: "#{ElixirconfChess.GameBoard.enemy(loser) |> Atom.to_string() |> String.capitalize()} Wins"
end
