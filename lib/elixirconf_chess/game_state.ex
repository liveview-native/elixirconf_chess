defmodule ElixirconfChess.GameState do
  defstruct board: ElixirconfChess.GameBoard.start_board(), turn: :white, spectators: [], white: nil, black: nil, state: :active
end
