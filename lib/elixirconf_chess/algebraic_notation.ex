defmodule ElixirconfChess.AlgebraicNotation do
  alias ElixirconfChess.GameBoard

  def move_algebra(%GameBoard.Move{ source: {x, _}, destination: target, value: {turn, piece, _}, capture: capture, state: state }) do
    capture = case capture do
      nil ->
        ""
      _ ->
        case piece do
          :pawn ->
            "#{file(x)}x"
          _ ->
            "x"
        end
    end
    algebra = "#{piece_algebra(piece)}#{position_algebra(origin)}#{position_algebra(target)}#{capture}"
    case state do
      {:checkmate, _} ->
        "#{algebra}#"
      {:active, {:check, checked}} ->
        if checked == GameBoard.enemy(turn) do
          "#{algebra}+"
        end
      _ ->
        algebra
    end
  end

  def piece_algebra(:king), do: "K"
  def piece_algebra(:queen), do: "Q"
  def piece_algebra(:rook), do: "R"
  def piece_algebra(:bishop), do: "B"
  def piece_algebra(:knight), do: "N"
  def piece_algebra(:pawn), do: ""

  def rank(y), do: 8 - y
  def file(x), do: List.to_string([Enum.at(?a..?h, x)])
  def position_algebra({x, y}), do: "#{file(x)}#{rank(y)}"
end
