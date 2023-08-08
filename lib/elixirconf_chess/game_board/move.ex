defmodule ElixirconfChess.GameBoard.Move do
  defstruct [:source, :destination]

  def new(source, destination), do: %__MODULE__{source: source, destination: destination}
end
