defmodule ElixirconfChess.GameBoard.Move do
  alias ElixirconfChess.GameBoard
  defstruct [:source, :destination, :value, :capture, :state]

  def new(state, source, destination), do: new(state, source, destination, false)
  def new(state, source, destination, true), do: %__MODULE__{
    source: source,
    destination: destination,
    value: GameBoard.value(state.board, source),
    capture: GameBoard.value(state.board, destination),
    state: GameBoard.game_state(%{ state | board: GameBoard.move(state, source, destination) })
  }
  def new(_state, source, destination, false), do: %__MODULE__{
    source: source,
    destination: destination,
    value: nil,
    capture: nil,
    state: nil
  }
end
