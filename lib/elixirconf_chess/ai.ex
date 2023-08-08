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
  @min_score -20
  @max_score 20

  def choose_next_move(board, current_player) do
    minimax(board, current_player, @minimax_depth)
  end

  defp minimax(board, current_player, depth, alpha \\ @min_score, beta \\ @max_score)
  defp minimax(board, _current_player, 0, _alpha, _beta) do
    eval(board)
  end

  defp minimax(board, current_player, depth, alpha, beta) do
    case GameBoard.game_state(board) do
      {:checkmate, ^current_player} -> 1000
      {:checkmate, _} -> -1000
      :draw -> 0
      _ ->
        # Here we can do some random sampling if we want to approximate MonteCarlo search instead
        moves = GameBoard.possible_moves(board, current_player, true)

        score = if current_player == :max_player do
          max_value(board, moves, depth, alpha, beta)
        else
          min_value(board, moves, depth, alpha, beta)
        end
        score
    end
  end

  defp max_value(board, [], _depth, alpha, _beta), do: eval(board)
  defp max_value(board, [move | rest], depth, alpha, beta) do
    # TO-DO: implement the move/2 function
    to_eval_board = GameBoard.move(board, move)
    score = minimax(to_eval_board, :min_player, depth - 1, alpha, beta)
    new_alpha = if score > alpha, do: score, else: alpha
    if new_alpha >= beta, do: new_alpha, else: max_value(board, rest, depth, new_alpha, beta)
  end

  defp min_value(board, [], _depth, _alpha, beta), do: eval(board)
  defp min_value(board, [move | rest], depth, alpha, beta) do
    # TO-DO: implement the move/2 function
    to_eval_board = GameBoard.move(board, move)
    score = minimax(to_eval_board, :max_player, depth - 1, alpha, beta)
    new_beta = if score < beta, do: score, else: beta
    if new_beta <= alpha, do: new_beta, else: min_value(board, rest, depth, alpha, new_beta)
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
        filename = Path.join(to_string(:code.priv_dir(:chess_ai)), "ai_weights.nx")
        params = filename |> File.read!() |> Nx.deserialize()

        # Build the prediction defn function
        {_init_fun, predict_fun} = Axon.build(model)

        inputs_template = %{
          "board" => Nx.template({batch_size, 8, 8, 14}, :u8)
          # "meta" => Nx.template({batch_size, 2}, :u8)
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
    board_input = Axon.input("board", shape: {nil, 8, 8, 14})
    # meta_input = Axon.input("meta", shape: {nil, 2})

    # board input is a tensor that contains channels for
    # pawn, rook, knight, bishop, queen and king for white and black, in this order.
    # 1 represents that the given (piece, color) combination is present in that position

    conv_batch_norm = fn layer, num_filters, kernel_size ->
      layer
      |> Axon.conv(num_filters, kernel_size: kernel_size, padding: :same, activation: :linear)
      |> Axon.batch_norm()
      |> Axon.relu()
    end

    res_net = fn input, num_filters, kernel_size ->
      first = conv_batch_norm.(input, num_filters, kernel_size)

      first
      |> conv_batch_norm.(num_filters, kernel_size)
      |> conv_batch_norm.(num_filters, kernel_size)
      |> Axon.add(first)
      |> Axon.relu()
    end

    board_net =
      board_input
      |> conv_batch_norm.(16, 3)
      |> res_net.(32, 3)
      |> conv_batch_norm.(16, 3)
      |> Axon.flatten()

    # meta_net = meta_input

    # precision_policy =
    #   Axon.MixedPrecision.create_policy(params: {:f, 32}, output: {:f, 32}, compute: {:f, 16})

    # Axon.concatenate([meta_net, board_net])
    eval_head =
      board_net
      |> Axon.dense(100, activation: :relu)
      |> Axon.dropout(rate: 0.5)
      |> Axon.dense(1, activation: :tanh)

    from_out =
      board_net
      |> Axon.dense(100, activation: :relu)
      |> Axon.dropout(rate: 0.5)
      |> Axon.dense(64, activation: :softmax)
      |> Axon.nx(&Nx.reshape(&1, {:auto, 1, 8, 8}))

    to_out =
      board_net
      |> Axon.dense(100, activation: :relu)
      |> Axon.dropout(rate: 0.5)
      |> Axon.dense(64, activation: :softmax)
      |> Axon.nx(&Nx.reshape(&1, {:auto, 1, 8, 8}))

    move_head = Axon.concatenate(from_out, to_out, axis: 1)

    Axon.container(%{eval: eval_head, move: move_head})
  end

  def board_to_input(board) do
    pieces_by_kind =
      board
      |> all_pieces()
      |> Enum.map(fn piece -> %{piece | row: 7 - piece.row} end)
      |> Enum.group_by(&{&1.type, &1.color})

    input_layers = Nx.broadcast(Nx.u8(0), {8, 8, 14})

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

        Nx.indexed_put(acc, indices, updates)
      end)

    # Fill attacked squares
    input_layers =
      input_layers
      |> set_squares_that_color_attacks(board, :white)
      |> set_squares_that_color_attacks(board, :black)

    %{"board" => input_layers}
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

        %{type: type, row: row, col: col} ->
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
end
