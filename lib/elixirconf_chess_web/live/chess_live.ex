defmodule ElixirconfChessWeb.ChessLive do
  use Phoenix.LiveView
  use LiveViewNative.LiveView

  import ElixirconfChessWeb.ChessComponents, only: [game_board: 1, player_chip: 1]
  alias ElixirconfChess.GameBoard

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      board: GameBoard.start_board,
      turn: :black,
      selection: nil,
      self_player: :white,
      moves: [],
      state: :active,
      liked: false
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
      <Text>
        <%= case @state do %>
        <% :active -> %>
          Active
        <% :draw -> %>
          Draw
        <% {:checkmate, :white} -> %>
          Checkmate - Black Wins
        <% {:checkmate, :black} -> %>
          Checkmate - White Wins
        <% end %>
      </Text>

      <Spacer />

      <.player_chip color={GameBoard.enemy(@self_player)} turn={@turn} board={@board} platform_id={:swiftui}>
        Enemy
      </.player_chip>

      <.game_board board={@board} selection={@selection} moves={@moves} turn={@turn} platform_id={:swiftui} native={@native} />

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
    {
      :noreply,
      socket
        |> select({String.to_integer(x), String.to_integer(y)})
        |> update(:moves, fn
          _, %{ selection: nil } -> []
          _, %{ board: board, selection: selection } -> GameBoard.possible_moves(board, selection)
        end)
        |> update(:state, fn _, %{ board: board } -> GameBoard.game_state(board) end)
    }
  end

  def select(socket, new_position) do
    case socket.assigns.state do
      :active ->
        if new_position == socket.assigns.selection do
          assign(socket, selection: nil)
        else
          is_valid_selection = !GameBoard.is_empty?(socket.assigns.board, new_position) and elem(GameBoard.value(socket.assigns.board, new_position), 0) == socket.assigns.turn
          case socket.assigns.selection do
            nil ->
              if is_valid_selection do
                assign(socket, selection: new_position)
              else
                assign(socket, selection: nil)
              end
            selection ->
              valid_moves = GameBoard.possible_moves(socket.assigns.board, selection)
              cond do
                Enum.member?(valid_moves, new_position) ->
                  assign(socket, board: GameBoard.move(socket.assigns.board, selection, new_position), selection: nil, turn: next_turn(socket.assigns.turn))
                is_valid_selection ->
                  assign(socket, selection: new_position)
                true ->
                  assign(socket, selection: nil)
              end
          end
        end
      _ ->
        assign(socket, selection: nil)
    end
  end

  def next_turn(:white), do: :black
  def next_turn(:black), do: :white
end
