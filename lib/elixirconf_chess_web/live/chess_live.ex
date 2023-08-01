defmodule ElixirconfChessWeb.ChessLive do
  use Phoenix.LiveView
  use LiveViewNative.LiveView

  import ElixirconfChessWeb.ChessComponents, only: [game_board: 1, player_chip: 1]
  alias ElixirconfChess.GameBoard

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      board: GameBoard.start_board,
      # board: %{
      #   #0 => %{
      #   #  0 => {:black, :rook, 1}, 1 => {:black, :knight, 2}, 2 => {:black, :bishop, 3}, 3 => {:black, :queen, 4}, 4 => {:black, :king, 5}, 5 => {:black, :bishop, 6}, 6 => {:black, :knight, 7}, 7 => {:black, :rook, 8}
      #   #},
      #   #1 => %{
      #   #  0 => {:black, :pawn, 9}, 1 => {:black, :pawn, 10}, 2 => {:black, :pawn, 11}, 3 => {:black, :pawn, 12}, 4 => {:black, :pawn, 13}, 5 => {:black, :pawn, 14}, 6 => {:black, :pawn, 15}, 7 => {:black, :pawn, 16}
      #   #},
      #   # ...
      #   6 => %{
      #     0 => {:white, :pawn, 17}, 1 => {:white, :pawn, 18}, 2 => {:white, :pawn, 19}, 3 => {:white, :pawn, 20}, 4 => {:white, :pawn, 21}, 5 => {:white, :pawn, 22}, 6 => {:white, :pawn, 23}, 7 => {:white, :pawn, 24}
      #   },
      #   7 => %{
      #     0 => {:white, :rook, 25}, 1 => {:white, :knight, 26}, 2 => {:white, :bishop, 27}, 3 => {:white, :queen, 28}, 4 => {:white, :king, 29}, 5 => {:white, :bishop, 30}, 6 => {:white, :knight, 31}, 7 => {:white, :rook, 32}
      #   },
      # },
      selection: nil, turn: :white, self_player: :white
    )}
  end

  def render(%{ platform_id: :swiftui, native: %{ platform_config: %{ user_interface_idiom: "watch" } } } = assigns) do
    ~SWIFTUI"""
    <VStack alignment="leading">
      <.game_board board={@board} selection={@selection} turn={@turn} platform_id={:swiftui} native={@native} />
    </VStack>
    """
  end

  def render(%{ platform_id: :swiftui } = assigns) do
    ~SWIFTUI"""
    <VStack alignment="leading" modifiers={navigation_title(title: "Chess") |> padding([])}>
      <Spacer />

      <.player_chip color={GameBoard.enemy(@self_player)} turn={@turn} board={@board} platform_id={:swiftui}>
        Enemy
      </.player_chip>

      <.game_board board={@board} selection={@selection} turn={@turn} board={@board} platform_id={:swiftui} native={@native} />

      <.player_chip color={@self_player} turn={@turn} board={@board} platform_id={:swiftui}>
        You
      </.player_chip>

      <Spacer />
    </VStack>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="w-full flex flex-col items-center">
      <p>TURN</p>
      <p class="text-4xl font-bold"><%= @turn |> Atom.to_string() |> String.capitalize() %></p>
      <.game_board board={@board} selection={@selection} turn={@turn} platform_id={:web} native={@native} />
    </div>
    """
  end

  def handle_event("select", %{ "x" => x, "y" => y }, socket) do
    new_position = {String.to_integer(x), String.to_integer(y)}
    if new_position == socket.assigns.selection do
      {:noreply, assign(socket, selection: nil)}
    else
      is_valid_selection = !GameBoard.is_empty?(socket.assigns.board, new_position) and elem(GameBoard.value(socket.assigns.board, new_position), 0) == socket.assigns.turn
      case socket.assigns.selection do
        nil ->
          if is_valid_selection do
            {:noreply, assign(socket, selection: new_position)}
          else
            {:noreply, assign(socket, selection: nil)}
          end
        selection ->
          valid_moves = GameBoard.possible_moves(socket.assigns.board, selection)
          cond do
            Enum.member?(valid_moves, new_position) ->
              {:noreply, assign(socket, board: GameBoard.move(socket.assigns.board, selection, new_position), selection: nil, turn: next_turn(socket.assigns.turn))}
            is_valid_selection ->
              {:noreply, assign(socket, selection: new_position)}
            true ->
              {:noreply, assign(socket, selection: nil)}
          end
      end
    end
  end

  def next_turn(:white), do: :black
  def next_turn(:black), do: :white
end
