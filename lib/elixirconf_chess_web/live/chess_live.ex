defmodule ElixirconfChessWeb.ChessLive do
  use Phoenix.LiveView
  use LiveViewNative.LiveView

  import ElixirconfChessWeb.ChessComponents, only: [game_board: 1, player_chip: 1]
  alias ElixirconfChess.PubSub
  alias ElixirconfChess.GameBoard
  alias ElixirconfChess.GameState
  alias ElixirconfChess.AlgebraicNotation

  alias ElixirconfChess.Game

  def mount(%{"id" => id}, _session, socket) do
    cond do
      !Game.alive?(id) ->
        {:ok, push_navigate(socket, to: "/", replace: false)}

      !connected?(socket) ->
        {:ok, assign(socket, :loading, true)}

      :else ->
        {player_color, game_state} = Game.join(id, false)

        PubSub.subscribe_game(id)

        can_add_ai_opponent =
          case GameState.opponent(game_state, player_color) do
            {:ok, _} -> true
            {:error, _} -> false
          end

        socket =
          socket
          |> assign(:game_id, id)
          |> assign(:game_state, game_state)
          |> assign(:player_color, player_color)
          |> assign(:selection, nil)
          |> assign(:show_promotion_picker, nil)
          |> assign(:promotion_type, nil)
          |> assign(:moves, [])
          |> assign(:loading, false)
          |> assign(:can_add_ai_opponent, can_add_ai_opponent)

        {:ok, socket}
    end
  end

  def render(
        %{platform_id: :swiftui, native: %{platform_config: %{user_interface_idiom: "watch"}}} =
          assigns
      ) do
    ~SWIFTUI"""
    <VStack alignment="leading">
      <.game_board game_state={@game_state} board={@game_state.board} selection={@selection} turn={@game_state.turn} platform_id={:swiftui} native={@native} />
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
        |> animation(animation: :default, value: Atom.to_string(@game_state.turn))
        |> confirmation_dialog(
          is_presented: @show_promotion_picker != nil,
          change: "promotion-dialog-changed",
          title: "Promote this pawn",
          title_visibility: :visible,
          actions: :promotion_actions
        )
      }
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

      <.player_chip
        game_state={@game_state}
        color={:black}
        turn={@game_state.turn}
        board={@game_state.board}
        platform_id={:swiftui}

        can_add_ai_opponent={@can_add_ai_opponent}
      >
        <%= if @player_color == :white, do: "Opponent", else: "You" %>
      </.player_chip>

      <.game_board game_state={@game_state} board={@game_state.board} selection={@selection} turn={@game_state.turn} platform_id={:swiftui} native={@native} />

      <.player_chip
        game_state={@game_state}
        color={:white}
        turn={@game_state.turn}
        board={@game_state.board}
        platform_id={:swiftui}

        can_add_ai_opponent={@can_add_ai_opponent}
      >
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
            <%= AlgebraicNotation.move_algebra(move) %>
          </Text>
        </HStack>
      </ScrollView>

      <Group template={:promotion_actions}>
        <Button
          :for={type <- [:queen, :rook, :knight, :bishop]}
          phx-click="promote"
          phx-value-promotion={type}
        >
          <%= type |> Atom.to_string() |> String.capitalize() %>
        </Button>
      </Group>
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
      <%= if @can_add_ai_opponent do %>
        <button phx-click="add_ai_opponent" style={"background-color: #{background_color(0, :web)};"} class="p-2 font-bold rounded">
          Play against Nx
        </button>
      <% end %>
      <%= case @game_state.state do %>
        <% :draw -> %>
          Draw
        <% {:checkmate, :white} -> %>
          Checkmate - Black Wins
        <% {:checkmate, :black} -> %>
          Checkmate - White Wins
        <% _ -> %>
          Turn:
            <p class="text-4xl font-bold"><%= @game_state.turn |> Atom.to_string() |> String.capitalize() %><span :if={@game_state.turn != @player_color}> (Not you)</span></p>
      <% end %>

      <.game_board game_state={@game_state} board={@game_state.board} selection={@selection} turn={@game_state.turn} platform_id={:web} native={@native} />

      <div class="flex flex-row overflow-x-scroll w-full max-w-2xl py-4">
        <p
          :for={{move, index} <- Enum.with_index(@game_state.move_history)}
          id={"move-#{length(@game_state.move_history) - index}"}
          class="px-4"
        >
          <%= AlgebraicNotation.move_algebra(move) %>
        </p>
      </div>

      <div :if={@show_promotion_picker != nil} class="absolute top-0 left-0 w-screen h-screen bg-black/25 z-50 flex flex-col justify-center">
        <div class="bg-white mx-auto rounded-lg p-4">
          <p class="text-lg font-bold mb-4">Promote this pawn</p>
          <div class="grid gap-4 grid-cols-2 grid-rows-2">
            <button
              :for={{piece, i} <- Enum.with_index([:queen, :rook, :knight, :bishop])}

              phx-click="promote"
              phx-value-promotion={piece}

              class="aspect-square flex overflow-clip rounded-lg"
              style={"background-color: #{ElixirconfChessWeb.Colors.web(if(rem(i, 3) == 0, do: :even_background, else: :odd_background))};"}
            >
              <div class="w-full h-full flex justify-center items-center">
                <p class={"text-5xl text-center " <> (if @game_state.turn == :white, do: "text-white", else: "text-black")}>
                  <%= GameBoard.piece(piece) %>
                </p>
              </div>
            </button>
          </div>
          <button class="w-full font-bold p-2 mt-4 rounded-lg" style={"background-color: #{ElixirconfChessWeb.Colors.web(:even_background)};"} phx-click="promote" phx-value-promotion="cancel">Cancel</button>
        </div>
      </div>
    </div>
    <pre :if={!@loading} hidden><%= inspect(@game_state, pretty: true) %></pre>
    """
  end

  def handle_event("add_ai_opponent", _, socket) do
    id = socket.assigns.game_id
    {player_color, _game_state} = Game.join(id, true)

    socket =
      socket
      |> put_flash(:success, "Added #{player_color} as AI")
      |> assign(:can_add_ai_opponent, false)

    {:noreply, socket}
  end

  def handle_event(
        "select",
        _,
        %{assigns: %{game_state: %GameState{turn: turn}, player_color: color}} = socket
      )
      when turn != color do
    {:noreply, put_flash(socket, :error, "Not your turn")}
  end

  def handle_event("promote", %{"promotion" => "cancel"}, socket) do
    {:noreply, assign(socket, :show_promotion_picker, nil)}
  end

  def handle_event("promote", %{"promotion" => promotion}, socket) do
    socket =
      socket
      |> assign(:promotion_type, String.to_existing_atom(promotion))
      |> assign(:show_promotion_picker, nil)
      |> select(socket.assigns.show_promotion_picker)
      |> assign(:moves, [])

    {:noreply, socket}
  end

  def handle_event("promotion-dialog-changed", %{"is_presented" => false}, socket) do
    {:noreply, assign(socket, :show_promotion_picker, nil)}
  end
  def handle_event("promotion-dialog-changed", _params, socket), do: {:noreply, socket}

  def handle_event("select", %{"x" => x, "y" => y}, socket) do
    socket =
      socket
      |> select({String.to_integer(x), String.to_integer(y)})
      |> update(:moves, fn
        _, %{selection: nil} ->
          []

        _, %{game_state: game_state, selection: selection} ->
          game_state
          |> GameBoard.possible_moves(selection)
          |> Enum.map(& &1.destination)
      end)

    {:noreply, socket}
  end

  def select(socket, new_position) do
    case socket.assigns.game_state.state do
      {:active, _} ->
        if new_position == socket.assigns.selection do
          assign(socket, selection: nil)
        else
          is_valid_selection =
            !GameBoard.is_empty?(socket.assigns.game_state.board, new_position) and
              elem(GameBoard.value(socket.assigns.game_state.board, new_position), 0) ==
                socket.assigns.game_state.turn

          case socket.assigns.selection do
            nil ->
              if is_valid_selection do
                assign(socket, selection: new_position)
              else
                assign(socket, selection: nil)
              end

            selection ->
              valid_moves =
                socket.assigns.game_state
                |> GameBoard.possible_moves(selection)
                |> Enum.map(& &1.destination)

              cond do
                Enum.member?(valid_moves, new_position) ->
                  if GameBoard.is_promotion?(GameBoard.value(socket.assigns.game_state.board, selection), new_position) and socket.assigns.promotion_type == nil do
                    assign(socket, :show_promotion_picker, new_position)
                  else
                    Game.move(socket.assigns.game_id, selection, new_position, socket.assigns.promotion_type)
                    assign(socket, :selection, nil)
                  end

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

  def handle_info({:game_update, id, game_state}, socket) do
    ^id = socket.assigns.game_id
    {:noreply, assign(socket, :game_state, game_state)}
  end

  def background_color(index, platform) when rem(index, 2) == 0,
    do: ElixirconfChessWeb.Colors.evaluate(:odd_background, platform)

  def background_color(_index, platform),
    do: ElixirconfChessWeb.Colors.evaluate(:even_background, platform)
end
