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
  @min_score -20_000
  @max_score 20_000

  def choose_move(board, current_player) do
    input = board_to_input(board, current_player)

    {probabilities, moves_idx} =
      Nx.Serving.batched_run(ChessAI.Serving, Nx.Batch.stack([input]), &Nx.backend_transfer/1)
      |> IO.inspect(label: "batched_run result")
      |> Nx.flatten()
      |> Nx.top_k(k: 5)
      |> IO.inspect(label: "topk moves")

    Enum.zip_with(Nx.to_list(probabilities), Nx.to_list(moves_idx), &{&1, &2})
    |> Enum.filter(&(elem(&1, 0) > 0))
    |> IO.inspect(label: "move pool")
    |> Enum.random()
    |> IO.inspect(label: "chosen idx")
    |> elem(1)
    |> index_to_move()
    |> then(fn %Move{source: {x, y}, destination: {dest_x, dest_y}} ->
      %Move{source: {x, 7 - y}, destination: {dest_x, 7 - dest_y}}
    end)
    |> IO.inspect(label: "chosen move")
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
          "board" => Nx.template({batch_size, 8, 8, 12}, :u8),
          "valid_moves_mask" => Nx.template({batch_size, 4096}, :u8)
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
    valid_moves_mask_input = Axon.input("valid_moves_mask", shape: {nil, 4096})
    # meta_input = Axon.input("meta", shape: {nil, 2})

    # board input is a tensor that contains channels for
    # pawn, rook, knight, bishop, queen and king for white and black, in this order.
    # 1 represents that the given (piece, color) combination is present in that position

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
      |> conv_batch_norm.(num_filters, kernel_size, :same, :relu, 1)
      |> conv_batch_norm.(num_filters, kernel_size, :same, :linear, 1)
      |> Axon.add(first)
      |> Axon.relu()
    end

    core =
      board_input
      |> res_net.(64, 3)
      |> res_net.(64, 3)
      |> res_net.(64, 3)
      |> res_net.(64, 3)
      |> Axon.conv(512, kernel_size: 8, feature_group_size: 64, activation: :linear)
      |> Axon.batch_norm()
      |> Axon.relu()
      |> Axon.flatten()

    model =
      core
      |> Axon.dense(1024, activation: :relu)
      |> Axon.dense(4096, activation: :linear)
      |> then(&Axon.multiply([&1, valid_moves_mask_input]))
      |> Axon.softmax()
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
          |> Enum.map(fn %{row: row, col: col} = piece ->
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
        move = Move.new({source_col, 7 - source_row}, {dest_col, 7 - dest_row})
        IO.inspect(move, label: "move")
        move_to_index(move)
      end)

    %{"board" => input_layers, "valid_moves_mask" => moves_mask(moves_idx)}
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

  def moves_mask(moves_idx) do
    moves_idx_t = Nx.tensor(moves_idx) |> Nx.new_axis(1)

    base = Nx.broadcast(Nx.u8(0), {4096})

    Nx.indexed_put(base, moves_idx_t, Nx.broadcast(Nx.u8(1), {Nx.size(moves_idx_t)}))
  end

  def move_to_index(move)
  def index_to_move(index)

  for start_sq <- 0..63, dest_sq <- 0..63 do
    start_move = {rem(start_sq, 8), div(start_sq, 8)}
    dest_move = {rem(dest_sq, 8), div(dest_sq, 8)}

    sq_idx = start_sq * 64 + dest_sq

    def move_to_index(%Move{source: unquote(start_move), destination: unquote(dest_move)}), do: unquote(sq_idx)
    def index_to_move(unquote(sq_idx)), do: %Move{source: unquote(start_move), destination: unquote(dest_move)}
  end
end
