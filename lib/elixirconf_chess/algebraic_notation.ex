defmodule ElixirconfChess.AlgebraicNotation do
  alias ElixirconfChess.GameBoard

  def move_algebra(board, new_board, {x, _} = origin, target) do
    {turn, piece, _} = GameBoard.value(board, origin)
    capture = case GameBoard.value(board, target) do
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
    algebra = "#{piece_algebra(piece)}#{capture}#{position_algebra(target)}"
    case GameBoard.game_state(new_board) do
      {:checkmate, _} ->
        "#{algebra}#"
      _ ->
        if GameBoard.in_check?(new_board, GameBoard.enemy(turn)) do
          "#{algebra}+"
        else
          algebra
        end
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
