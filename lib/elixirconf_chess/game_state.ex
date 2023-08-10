defmodule ElixirconfChess.GameState do
  defstruct board: ElixirconfChess.GameBoard.start_board(),
            turn: :white,
            spectators: [],
            white: nil,
            black: nil,
            white_is_ai: false,
            black_is_ai: false,
            state: {:active, nil},
            move_history: []

  def description(%{ state: {:active, {:check, checked}} }), do: "Check #{checked |> Atom.to_string |> String.capitalize}"
  def description(%{ state: {:active, _}, turn: turn }), do: "#{turn |> Atom.to_string |> String.capitalize}'s Turn"
  def description(%{ state: :draw }), do: "Draw"
  def description(%{ state: {:checkmate, loser} }), do: "#{ElixirconfChess.GameBoard.enemy(loser) |> Atom.to_string |> String.capitalize} Wins"

  def opponent(%{white: pid}, :black), do: {:ok, pid}
  def opponent(%{black: pid}, :white), do: {:ok, pid}
  def opponent(_, _spectator), do: {:error, :spectator}
end
