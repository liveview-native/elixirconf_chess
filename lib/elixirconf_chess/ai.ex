defmodule ElixirconfChess.AI do
  @moduledoc """
  Documentation for `ElixirconfChess.AI`.
  """

  alias ElixirconfChess.GameBoard
  alias ElixirconfChess.GameBoard.Move

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
  @top_k_moves 5

  def choose_move(board, current_player, depth \\ @minimax_depth, k \\ @top_k_moves) do
    {eval, %Move{source: {sx, sy}, destination: {dx, dy}}} =
      minimax(board, depth, -100, 100, current_player == :white, k)

    {eval, %Move{source: {sx, sy}, destination: {dx, dy}}}
  end

  defp minimax(board, 0, _, _, _, _), do: {eval_board(board), nil}

  defp minimax(board, depth, alpha, beta, is_max_player, k) do
    moves = get_moves(board, k, is_max_player)
    best_move = nil

    eval_fn =
      if is_max_player do
        fn move, alpha, best_move ->
          board_with_move = GameBoard.move(board, move)
          {evaluation, _} = minimax(board_with_move, depth - 1, alpha, beta, false, k)
          new_alpha = if evaluation > alpha, do: evaluation, else: alpha
          new_best_move = if evaluation > alpha, do: move, else: best_move

          if beta <= new_alpha do
            {:halt, {new_alpha, new_best_move}}
          else
            {:cont, {new_alpha, new_best_move}}
          end
        end
      else
        fn move, beta, best_move ->
          board_with_move = GameBoard.move(board, move)
          {evaluation, _} = minimax(board_with_move, depth - 1, alpha, beta, true, k)
          new_beta = if evaluation < beta, do: evaluation, else: beta
          new_best_move = if evaluation < beta, do: move, else: best_move

          if new_beta <= alpha do
            {:halt, {new_beta, new_best_move}}
          else
            {:cont, {new_beta, new_best_move}}
          end
        end
      end

    best_score = if is_max_player, do: -100, else: 100

    {value, best_move} =
      Enum.reduce_while(moves, {best_score, best_move}, fn move, acc ->
        eval_fn.(move, elem(acc, 0), elem(acc, 1))
      end)

    {value, best_move}
  end

  defp get_moves(board, k, current_player) do
    current_player = if current_player, do: :white, else: :black
    {input, valid_moves_idx} = board_to_input(board, current_player)

    if valid_moves_idx == [] do
      []
    else
      {probabilities, moves_idx} =
        Nx.Serving.batched_run(ChessAI.Serving, Nx.Batch.stack([Map.take(input, ["board"])]), &Nx.backend_transfer/1)
        |> Nx.flatten()
        |> Nx.multiply(input["valid_moves_mask"])
        |> then(fn t ->
          Nx.divide(t, Nx.add(Nx.sum(t), 1.0e-7))
        end)
        |> Nx.top_k(k: k)

      Enum.zip_with(Nx.to_list(probabilities), Nx.to_list(moves_idx), &{&1, &2})
      |> Enum.filter(&(elem(&1, 0) > 0))
      |> Enum.map(&index_to_move(elem(&1, 1)))
    end
  end

  defp eval_board(board) do
    board
    |> all_pieces()
    |> Enum.reduce(0, &(&2 + eval_piece(&1)))
  end

  defp eval_piece(%{color: :white, type: :pawn}), do: 1
  defp eval_piece(%{color: :white, type: :rook}), do: 5
  defp eval_piece(%{color: :white, type: :knight}), do: 3
  defp eval_piece(%{color: :white, type: :bishop}), do: 3
  defp eval_piece(%{color: :white, type: :queen}), do: 9
  defp eval_piece(%{color: :white, type: :king}), do: 0
  defp eval_piece(%{color: :black, type: :pawn}), do: -1
  defp eval_piece(%{color: :black, type: :rook}), do: -5
  defp eval_piece(%{color: :black, type: :knight}), do: -3
  defp eval_piece(%{color: :black, type: :bishop}), do: -3
  defp eval_piece(%{color: :black, type: :queen}), do: -9
  defp eval_piece(%{color: :black, type: :king}), do: 0

  def serving do
    # Configuration
    batch_size = 20
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
          "board" => Nx.template({batch_size, 8, 8, 12}, :u8)
        }

        template_args = [Nx.to_template(params), inputs_template]

        # Compile the prediction function upfront for the configured batch_size
        predict_fun = Nx.Defn.compile(predict_fun, template_args, defn_options)

        # The returned function is called for every accumulated batch
        fn inputs ->
          inputs = Nx.Batch.pad(inputs, batch_size - inputs.size)
          predict_fun.(params, inputs)
        end
      end,
      batch_size: batch_size
    )
  end

  defp model do
    board_input = Axon.input("board", shape: {nil, 8, 8, 12})

    conv_batch_norm = fn layer, num_filters, kernel_size, padding, activation, kernel_dilation ->
      layer
      |> Axon.conv(num_filters,
        kernel_size: kernel_size,
        padding: padding,
        activation: :linear,
        kernel_dilation: kernel_dilation
      )
      |> Axon.batch_norm()
      |> Axon.activation(activation)
    end

    res_net = fn input, num_filters, kernel_size ->
      first = conv_batch_norm.(input, num_filters, kernel_size, :same, :relu, 1)

      first
      |> conv_batch_norm.(num_filters, kernel_size, :same, :linear, 1)
      |> Axon.add(first)
      |> Axon.relu()
    end

    core =
      board_input
      |> res_net.(64, 3)
      |> res_net.(64, 3)
      |> res_net.(64, 3)
      |> Axon.conv(512, kernel_size: 8, feature_group_size: 64, activation: :linear)
      |> Axon.batch_norm()
      |> Axon.relu()
      |> Axon.flatten()

    core
    |> Axon.dense(1024, activation: :relu)
    |> Axon.dense(4096, activation: :softmax)
  end

  def board_to_input(board, current_player) do
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
      |> Enum.reject(fn {pieces, _} -> pieces == [] or is_nil(pieces) end)
      |> Enum.reduce(input_layers, fn {pieces, layer_index}, acc ->
        indices =
          pieces
          |> Enum.map(fn %{row: row, col: col} ->
            [row, col, layer_index]
          end)
          |> Nx.tensor()

        updates = Nx.broadcast(Nx.u8(1), {Nx.axis_size(indices, 0)})

        Nx.indexed_add(acc, indices, updates)
      end)

    moves_idx =
      board
      |> GameBoard.possible_moves(current_player, true)
      |> Enum.map(fn %{source: {source_col, source_row}, destination: {dest_col, dest_row}} ->
        move = Move.new({source_col, source_row}, {dest_col, dest_row})
        move_to_index(move)
      end)

    {
      %{"board" => input_layers, "valid_moves_mask" => moves_mask(moves_idx)},
      moves_idx
    }
  end

  defp all_pieces(board) do
    Enum.reduce(board, [], fn {row, pieces_by_row}, acc ->
      Enum.reduce(pieces_by_row, [], fn
        {col, {color, type, _}}, acc ->
          [%{color: color, type: type, row: row, col: col} | acc]

        _, acc ->
          acc
      end) ++ acc
    end)
  end

  def moves_mask([]), do: nil

  def moves_mask(moves_idx) do
    moves_idx_t = Nx.tensor(moves_idx) |> Nx.new_axis(1)

    base = Nx.broadcast(Nx.u8(0), {4096})

    Nx.indexed_put(base, moves_idx_t, Nx.broadcast(Nx.u8(1), {Nx.size(moves_idx_t)}))
  end

  def move_to_index(move)
  def index_to_move(index)

  for start_sq <- 0..63, dest_sq <- 0..63 do
    start_move = {rem(start_sq, 8), 7 - div(start_sq, 8)}
    dest_move = {rem(dest_sq, 8), 7 - div(dest_sq, 8)}

    sq_idx = start_sq * 64 + dest_sq

    def move_to_index(%Move{source: unquote(start_move), destination: unquote(dest_move)}), do: unquote(sq_idx)
    def index_to_move(unquote(sq_idx)), do: %Move{source: unquote(start_move), destination: unquote(dest_move)}
  end
end
