defmodule ElixirconfChess.GameBoard do
  @start_board %{
    0 => %{
      0 => {:black, :rook, 1}, 1 => {:black, :knight, 2}, 2 => {:black, :bishop, 3}, 3 => {:black, :queen, 4}, 4 => {:black, :king, 5}, 5 => {:black, :bishop, 6}, 6 => {:black, :knight, 7}, 7 => {:black, :rook, 8}
    },
    1 => %{
      0 => {:black, :pawn, 9}, 1 => {:black, :pawn, 10}, 2 => {:black, :pawn, 11}, 3 => {:black, :pawn, 12}, 4 => {:black, :pawn, 13}, 5 => {:black, :pawn, 14}, 6 => {:black, :pawn, 15}, 7 => {:black, :pawn, 16}
    },
    # ...
    6 => %{
      0 => {:white, :pawn, 17}, 1 => {:white, :pawn, 18}, 2 => {:white, :pawn, 19}, 3 => {:white, :pawn, 20}, 4 => {:white, :pawn, 21}, 5 => {:white, :pawn, 22}, 6 => {:white, :pawn, 23}, 7 => {:white, :pawn, 24}
    },
    7 => %{
      0 => {:white, :rook, 25}, 1 => {:white, :knight, 26}, 2 => {:white, :bishop, 27}, 3 => {:white, :queen, 28}, 4 => {:white, :king, 29}, 5 => {:white, :bishop, 30}, 6 => {:white, :knight, 31}, 7 => {:white, :rook, 32}
    },
  }

  def start_board, do: @start_board

  def x_range, do: 0..7
  def y_range, do: 0..7

  def value(board, {x, y}), do: board |> Map.get(y, %{}) |> Map.get(x)

  def is_empty?(board, position), do: value(board, position) == nil

  def is_self?(turn, board, position) do
    case value(board, position) do
      {^turn, _, _} ->
        true
      _ ->
        false
    end
  end

  def locate(board, {turn, piece}) do
    Enum.reduce(
      board,
      nil,
      fn {y, row}, acc ->
        row_match = Enum.reduce(
          row,
          nil,
          fn
            {x, {^turn, ^piece, _}}, _ -> {x, y}
            _, acc -> acc
          end
        )
        case row_match do
          nil ->
            acc
          value ->
            value
        end
      end
    )
  end

  def is_enemy?(turn, board, position) do
    case value(board, position) do
      {^turn, _, _} ->
        false
      nil ->
        false
      _ ->
        true
    end
  end

  def is_on_board?({x, y}), do: x >= 0 and y >= 0 and x <= 7 and y <= 7

  def enemy(:white), do: :black
  def enemy(:black), do: :white

  def piece(board, position) do
    case value(board, position) do
      nil ->
        {:white, "", nil}
      {color, type, id} ->
        {color, piece(type), id}
    end
  end

  def piece(:king), do: "♚"
  def piece(:queen), do: "♛"
  def piece(:rook), do: "♜"
  def piece(:bishop), do: "♝"
  def piece(:knight), do: "♞"
  def piece(:pawn), do: "♟︎"

  def possible_moves(board, turn) when turn in [:white, :black] do
    Enum.reduce(
      board,
      [],
      fn {y, row}, acc -> acc ++ row_moves(board, y, row, turn) end
    )
  end

  def possible_moves(board, {x, y} = position) when is_number(x) and is_number(y) do
    position_value = value(board, position)
    {turn, _, _} = position_value
    case possible_moves(board, position, position_value) do
      [] -> []
      moves ->
        Enum.filter(moves, fn target ->
          !in_check?(move(board, position, target), turn)
        end) # the player cannot put themselves in check
    end
  end

  def possible_moves(_board, _position, nil), do: []

  def possible_moves(board, {x, y}, {turn, :pawn, _}) do
    {start, direction} = case turn do
      :white ->
        {6, -1}
      :black ->
        {1, 1}
    end
    captures = for p <- (for i <- [-1, 1], do: {x + i, y + direction}), is_enemy?(turn, board, p), do: p
    next = {x, y + direction}
    if is_empty?(board, next) do
      moves = [next | captures]
      if y == start do
        next = {x, y + (direction * 2)}
        if is_empty?(board, next) do
          [next | moves]
        else
          moves
        end
      else
        moves
      end
    else
      captures
    end
  end

  def possible_moves(board, {x, y}, {turn, :rook, _}) do
    Enum.concat([
      directional_moves([], turn, board, {x - 1, y}, {-1, 0}),
      directional_moves([], turn, board, {x + 1, y}, {1, 0}),
      directional_moves([], turn, board, {x, y - 1}, {0, -1}),
      directional_moves([], turn, board, {x, y + 1}, {0, 1}),
    ])
  end

  def possible_moves(board, {x, y}, {turn, :knight, _}) do
    moves = [
      {x - 2, y - 1}, {x - 2, y + 1}, {x + 2, y - 1}, {x + 2, y + 1},
      {x - 1, y - 2}, {x - 1, y + 2}, {x + 1, y - 2}, {x + 1, y + 2},
    ]
    for p <- moves, is_on_board?(p) and !is_self?(turn, board, p), do: p
  end

  def possible_moves(board, {x, y}, {turn, :bishop, _}) do
    Enum.concat([
      directional_moves([], turn, board, {x - 1, y - 1}, {-1, -1}),
      directional_moves([], turn, board, {x + 1, y - 1}, {1, -1}),
      directional_moves([], turn, board, {x - 1, y + 1}, {-1, 1}),
      directional_moves([], turn, board, {x + 1, y + 1}, {1, 1}),
    ])
  end

  def possible_moves(board, {x, y}, {turn, :queen, _}) do
    Enum.concat([
      directional_moves([], turn, board, {x - 1, y}, {-1, 0}),
      directional_moves([], turn, board, {x + 1, y}, {1, 0}),
      directional_moves([], turn, board, {x, y - 1}, {0, -1}),
      directional_moves([], turn, board, {x, y + 1}, {0, 1}),

      directional_moves([], turn, board, {x - 1, y - 1}, {-1, -1}),
      directional_moves([], turn, board, {x + 1, y - 1}, {1, -1}),
      directional_moves([], turn, board, {x - 1, y + 1}, {-1, 1}),
      directional_moves([], turn, board, {x + 1, y + 1}, {1, 1}),
    ])
  end

  def possible_moves(board, {x, y}, {turn, :king, _}) do
    moves = [
      {x - 1, y}, {x - 1, y + 1}, {x - 1, y - 1},
      {x + 1, y}, {x + 1, y + 1}, {x + 1, y - 1},
      {x, y - 1}, {x, y + 1}
    ]
    for p <- moves, is_on_board?(p) and !is_self?(turn, board, p), do: p
  end

  defp row_moves(board, y, row, turn) do
    Enum.reduce(
      row,
      [],
      fn
        {x, {^turn, _, _} = value}, acc -> acc ++ possible_moves(board, {x, y}, value)
        _, acc -> acc
      end
    )
  end

  def directional_moves(moves, turn, board, {x, y} = position, {dx, dy} = direction) do
    cond do
      !is_on_board?(position) ->
        moves
      is_self?(turn, board, position) ->
        moves
      !is_empty?(board, position) ->
        [position | moves]
      true ->
        directional_moves([position | moves], turn, board, {x + dx, y + dy}, direction)
    end
  end

  def move(board, {origin_x, origin_y} = origin, {x, y}) do
    piece = value(board, origin)
    # remove the piece from its old position
    board = Map.get_and_update(board, origin_y, fn row -> {row, Map.pop(row, origin_x) |> elem(1)} end) |> elem(1)
    # put the piece in its new position
    if Map.has_key?(board, y) do
      Map.get_and_update(board, y, fn row -> {row, Map.put(row, x, piece)} end) |> elem(1)
    else
      Map.put(board, y, %{ x => piece })
    end
  end

  def format_position({x, y}), do: "#{List.to_string([Enum.at(?a..?h, x)])}#{8 - y}"

  def in_check?(board, turn) do
    king = locate(board, {turn, :king})
    possible_moves(board, enemy(turn)) |> Enum.member?(king)
  end

  def all_pieces(board) do
    Enum.reduce(
      board,
      [],
      fn {_, row}, acc ->
        acc ++ Enum.reduce(
          row,
          [],
          fn
            {_, piece}, acc ->
              [piece | acc]
            _, acc ->
              acc
          end
        )
      end
    )
  end

  def captures(board, turn) do
    enemy = enemy(turn)
    current_pieces = all_pieces(board)
    Enum.filter(
      all_pieces(start_board()),
      fn
        {^enemy, _, _} = piece ->
          !Enum.member?(current_pieces, piece)
        _ ->
          false
      end
    )
  end
end
