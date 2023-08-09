defmodule ElixirconfChess.AI do
  @moduledoc """
  Documentation for `ElixirconfChess.AI`.
  """

  alias ElixirconfChess.GameBoard

  @piece_layers [
    {:pawn, :white},
    {:rook, :white},
    {:knight, :white},
    {:bishop, :white},
    {:queen, :white},
    {:king, :white},
    {:pawn, :black},
    {:rook, :black},
    {:knight, :black},
    {:bishop, :black},
    {:queen, :black},
    {:king, :black}
  ]

  @minimax_depth 3
  @min_score -20_000
  @max_score 20_000

  def choose_move(board) do
    input = board_to_input(board)

    %Move{} =
      move =
      Nx.Serving.batched_run(ChessAI.Serving, Nx.Batch.stack([input]))
      |> Nx.flatten()
      |> Nx.to_number()
      |> move_index_to_source_dest()

    to_eval_board = GameBoard.move(board, move)
  end

  def serving do
    # Configuration
    batch_size = 4
    defn_options = [compiler: EXLA]

    Nx.Serving.new(
      # This function runs on the serving startup
      fn ->
        # Build the Axon model and load params (usually from file)
        model = model()
        filename = Path.join(to_string(:code.priv_dir(:elixirconf_chess)), "ai_weights.nx")
        params = filename |> File.read!() |> Nx.deserialize()

        # Build the prediction defn function
        {_init_fun, predict_fun} = Axon.build(model)

        inputs_template = %{
          "board" => Nx.template({batch_size, 8, 8, 1}, :s8)
          # "meta" => Nx.template({batch_size, 2}, :u8)
        }

        template_args = [Nx.to_template(params), inputs_template]

        # Compile the prediction function upfront for the configured batch_size
        predict_fun = Nx.Defn.compile(predict_fun, template_args, defn_options)

        # The returned function is called for every accumulated batch
        fn inputs ->
          inputs = Nx.Batch.pad(inputs, batch_size - inputs.size)
          predict_fun.(params, %{"board" => inputs})
        end
      end,
      batch_size: batch_size
    )
  end

  defp model do
    board_input = Axon.input("board", shape: {nil, 8, 8, 1})

    model =
      board_input
      |> Axon.flatten()
      |> Axon.dense(512, activation: :relu)
      |> Axon.dense(1024, activation: :relu)
      |> Axon.dense(512, activation: :relu)
      |> Axon.dense(1, activation: :tanh)
  end

  def board_to_input(board) do
    pieces_by_kind =
      board
      |> all_pieces()
      |> Enum.map(fn piece -> %{piece | row: 7 - piece.row} end)
      |> Enum.group_by(&{&1.type, &1.color})

    input_layers = Nx.broadcast(Nx.u8(0), {8, 8, 12})

    input_layers =
      @piece_layers
      |> Enum.with_index(fn layer_key, layer_index ->
        pieces = pieces_by_kind[layer_key]

        {pieces, layer_index}
      end)
      |> Enum.reject(fn {pieces, _} -> pieces == [] end)
      |> Enum.reduce(input_layers, fn {pieces, layer_index}, acc ->
        indices =
          pieces
          |> Enum.map(fn %{row: row, col: col} = piece ->
            [row, col, layer_index]
          end)
          |> Nx.tensor()

        updates = Nx.broadcast(Nx.u8(1), {Nx.axis_size(indices, 0)})

        Nx.indexed_add(acc, indices, updates)
      end)

    move_idx =
      board
      |> GameBoard.possible_moves(current_player, true)
      |> Enum.map(fn %{source: {source_x, source_y}, destination: {dest_x, dest_y}} ->
        move = Move.new({source_x, 7 - source_y}, {dest_x, 7 - dest_y})
        move_to_index(move)
      end)

    %{"board" => input_layers, "valid_moves_mask" => moves_mask(moves)}
  end

  defp all_pieces(board) do
    Enum.flat_map(board, fn {row, pieces_by_row} ->
      Enum.map(pieces_by_row, fn {col, {color, type, _}} ->
        %{color: color, type: type, row: row, col: col}
      end)
    end)
  end

  defp set_squares_that_color_attacks(tensor, board, color) do
    idx =
      case color do
        :white -> 12
        :black -> 13
      end

    indices =
      board
      |> all_pieces()
      |> Enum.filter(&(&1.color == color))
      |> Enum.flat_map(fn
        %{type: :pawn, row: row, col: col} ->
          direction =
            if color == :white do
              -1
            else
              1
            end

          # put_in is so that we can trick the
          # possible_moves function into returning
          # only attacking moves for the pawn
          board
          |> put_in([row, col + direction], nil)
          |> GameBoard.possible_moves({row, col})

        %{type: _type, row: row, col: col} ->
          GameBoard.possible_moves(board, {row, col})
      end)
      |> Enum.map(fn {x, y} ->
        [7 - x, y, idx]
      end)

    case indices do
      [] ->
        tensor

      _ ->
        indices = Nx.tensor(indices)
        updates = Nx.broadcast(Nx.u8(1), {Nx.axis_size(indices, 0)})

        Nx.indexed_put(board, indices, updates)
    end
  end

  defp moves_mask(moves_idx) do
    moves_idx_t = Nx.tensor(moves_idx)

    base = Nx.broadcast(Nx.u8(0), {1, 4096})

    Nx.indexed_put(base, moves_idx_t, Nx.broadcast(Nx.u8(1), {Nx.size(moves_idx_t)}))
  end

  defp move_to_index(move)
  defp index_to_move(index)

  for start_sq <- 0..63, dest_sq <- 0..63 do
    start_move = {rem(start_sq, 8), div(start_sq, 8)}
    dest_move = {rem(dest_sq, 8), div(dest_sq, 8)}

    sq_idx = start_sq * 64 + dest_sq

    defp move_to_index(%Move{source: unquote(start_move), destination: unquote(dest_move)}), do: unquote(sq_idx)
    defp index_to_move(unquote(sq_idx)), do: %Move{source: unquote(start_move), destination: unquote(dest_move)}
  end
end
