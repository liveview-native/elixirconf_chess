defmodule ElixirconfChessWeb.IndexLive do
  use Phoenix.LiveView
  use LiveViewNative.LiveView

  import ElixirconfChessWeb.ChessComponents, only: [game_board: 1]
  alias ElixirconfChess.GameBoard

  def mount(_params, _session, socket) do
    {:ok, assign(socket, board: GameBoard.start_board, selection: nil, turn: :white)}
  end

  def render(%{ platform_id: :swiftui } = assigns) do
    ~SWIFTUI"""
    <VStack alignment="leading">
      <VStack alignment="leading" modifiers={padding([])}>
        <Text modifiers={font(font: {:system, :caption})}>TURN</Text>
        <Text modifiers={font(font: {:system, :title, [weight: :bold]})}><%= @turn |> Atom.to_string() |> String.capitalize() %></Text>
      </VStack>
      <Spacer />

      <.game_board board={@board} selection={@selection} turn={@turn} platform_id={:swiftui} />

      <Spacer />
    </VStack>
    """
  end

  def render(assigns) do
    ~H"""
    <p>Welcome to Chess</p>
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

  def next_turn(turn) do
    case turn do
      :white ->
        :black
      :black ->
        :white
    end
  end
end
