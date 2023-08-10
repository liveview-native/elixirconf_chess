defmodule ElixirconfChess.GameBoard.Move do
  alias ElixirconfChess.GameBoard
  defstruct [:source, :destination, :value, :capture, :state]

  def new(board, source, destination), do: new(board, source, destination, false)
  def new(board, source, destination, true), do: %__MODULE__{
    source: source,
    destination: destination,
    value: GameBoard.value(board, source),
    capture: GameBoard.value(board, destination),
    state: GameBoard.game_state(GameBoard.move(board, source, destination))
  }
  def new(board, source, destination, false), do: %__MODULE__{
    source: source,
    destination: destination,
    value: nil,
    capture: nil,
    state: nil
  }
end
