defmodule ElixirconfChessWeb.ChessLive do
  use Phoenix.LiveView
  use LiveViewNative.LiveView

  import ElixirconfChessWeb.ChessComponents, only: [game_board: 1, player_chip: 1]
  alias ElixirconfChess.GameBoard
  alias ElixirconfChess.GameState

  alias ElixirconfChess.Game

  def mount(%{"id" => id}, _session, socket) do
    cond do
      !Game.alive?(id) ->
        {:ok, push_navigate(socket, to: "/", replace: false)}

      !connected?(socket) ->
        {:ok, assign(socket, :loading, true)}

      :else ->
        {player_color, game_state} = Game.join(id)

        socket =
          socket
          |> assign(:game_id, id)
          |> assign(:game_state, game_state)
          |> assign(:player_color, player_color)
          |> assign(:selection, nil)
          |> assign(:moves, [])
          |> assign(:loading, false)

        {:ok, socket}
    end
  end

  def render(%{platform_id: :swiftui, native: %{platform_config: %{user_interface_idiom: "watch"}}} = assigns) do
    ~SWIFTUI"""
    <VStack alignment="leading">
      <.game_board board={@game_state.board} selection={@selection} turn={@game_state.turn} platform_id={:swiftui} native={@native} />
    </VStack>
    """
  end

  def render(%{platform_id: :swiftui} = assigns) do
    ~SWIFTUI"""
    <VStack
      alignment="leading"
      modifiers={
        navigation_title(title: "Chess")
        |> toolbar(content: :toolbar)
        |> padding([])
        |> animation(animation: :default, value: Atom.to_string(@game_state.turn))}
    >
      <Group template={:toolbar}>
        <ToolbarItem placement="principal">
          <Text
            modifiers={
              padding(:horizontal, 8)
              |> padding(:vertical, 4)
              |> font(font: {:system, :subheadline, [weight: :bold]})
              |> foreground_style({:color, :white})
              |> background(ElixirconfChessWeb.Colors.swiftui(:odd_background), in: :capsule)
            }
          >
            <%= ElixirconfChess.GameState.description(@game_state) %>
          </Text>
        </ToolbarItem>
        <ToolbarItem placement="primary-action">
          <ShareLink subject="Compete against me in Chess!" item={"elixirconfchess://#{@game_id}"} />
        </ToolbarItem>
      </Group>

      <.player_chip color={:black} turn={@game_state.turn} board={@game_state.board} platform_id={:swiftui}>
        <%= if @player_color == :white, do: "Opponent", else: "You" %>
      </.player_chip>

      <.game_board board={@game_state.board} selection={@selection} turn={@game_state.turn} platform_id={:swiftui} native={@native} />

      <.player_chip color={:white} turn={@game_state.turn} board={@game_state.board} platform_id={:swiftui}>
        <%= if @player_color == :white, do: "You", else: "Opponent" %>
      </.player_chip>

      <Spacer />

      <Text modifiers={font(font: {:system, :headline})}>Moves</Text>
      <ScrollView axes="horizontal" modifiers={foreground_style({:hierarchical, :secondary}) |> font(font: {:system, :subheadline})}>
        <HStack modifiers={padding(:bottom)}>
          <Text
            :for={{move, index} <- Enum.with_index(@game_state.move_history)}
            id={"move-#{length(@game_state.move_history) - index}"}
            modifiers={padding(:horizontal, 4)}
          >
            <%= move %>
          </Text>
        </HStack>
      </ScrollView>
    </VStack>
    """
  end

  def render(assigns) do
    ~H"""
    <a href="/">Back to Lobby</a>
    <div :if={@loading} class="w-full flex flex-col items-center">
      Loading
    </div>
    <div :if={!@loading} class="w-full flex flex-col items-center">
      <p>You: <%= @player_color %></p>
      <%= case @game_state.state do %>
        <% :active -> %>
          Turn:
          <p class="text-4xl font-bold"><%= @game_state.turn |> Atom.to_string() |> String.capitalize() %><span :if={@game_state.turn != @player_color}> (Not you)</span></p>
        <% :draw -> %>
          Draw
        <% {:checkmate, :white} -> %>
          Checkmate - Black Wins
        <% {:checkmate, :black} -> %>
          Checkmate - White Wins
      <% end %>

      <.game_board board={@game_state.board} selection={@selection} turn={@game_state.turn} platform_id={:web} native={@native} />
    </div>
    <pre :if={!@loading} hidden><%= inspect(@game_state, pretty: true) %></pre>
    """
  end

  def handle_event("select", _, %{assigns: %{game_state: %GameState{turn: turn}, player_color: color}} = socket) when turn != color do
    {:noreply, put_flash(socket, :error, "Not your turn")}
  end

  def handle_event("select", %{"x" => x, "y" => y}, socket) do
    socket =
      socket
      |> select({String.to_integer(x), String.to_integer(y)})
      |> update(:moves, fn
        _, %{selection: nil} -> []
        _, %{game_state: %GameState{board: board}, selection: selection} -> GameBoard.possible_moves(board, selection)
      end)

    {:noreply, socket}
  end

  def select(socket, new_position) do
    case socket.assigns.game_state.state do
      :active ->
        if new_position == socket.assigns.selection do
          assign(socket, selection: nil)
        else
          is_valid_selection =
            !GameBoard.is_empty?(socket.assigns.game_state.board, new_position) and elem(GameBoard.value(socket.assigns.game_state.board, new_position), 0) == socket.assigns.game_state.turn

          case socket.assigns.selection do
            nil ->
              if is_valid_selection do
                assign(socket, selection: new_position)
              else
                assign(socket, selection: nil)
              end

            selection ->
              valid_moves = GameBoard.possible_moves(socket.assigns.game_state.board, selection)

              cond do
                Enum.member?(valid_moves, new_position) ->
                  case Game.move(socket.assigns.game_id, selection, new_position) do
                    :not_your_turn -> socket
                    new_game_state -> assign(socket, :game_state, new_game_state)
                  end
                  |> assign(:selection, nil)

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

  def handle_info({:game_state_update, game_state}, socket) do
    {:noreply, assign(socket, :game_state, game_state)}
  end
end
