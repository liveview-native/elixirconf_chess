defmodule ElixirconfChessWeb.ChessLive do
  use ElixirconfChessWeb, :live_view
  use ElixirconfChessWeb.Styles.AppStyles

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
        %{format: :swiftui, native: %{platform_config: %{user_interface_idiom: "watch"}}} =
          assigns
      ) do
    ~SWIFTUI"""
    <ScrollView
      class="navigation-title title-inline"
      title={ElixirconfChess.GameState.description(@game_state)}
    >
      <VStack alignment="leading">
        <.player_chip
          game_state={@game_state}
          color={:black}
          turn={@game_state.turn}
          board={@game_state.board}
          format={:swiftui}

          can_add_ai_opponent={@can_add_ai_opponent}
        >
          <%= chip_label(:black, @player_color, @game_state) %>
        </.player_chip>
        <.game_board game_state={@game_state} board={@game_state.board} selection={@selection} turn={@game_state.turn} format={:swiftui} />
        <.player_chip
          game_state={@game_state}
          color={:white}
          turn={@game_state.turn}
          board={@game_state.board}
          format={:swiftui}

          can_add_ai_opponent={@can_add_ai_opponent}
        >
          <%= chip_label(:white, @player_color, @game_state) %>
        </.player_chip>
      </VStack>
    </ScrollView>
    """
  end

  def render(%{format: :swiftui} = assigns) do
    ~SWIFTUI"""
    <VStack
      alignment="leading"
      class="navigation-title toolbar:toolbar padding animation confirmation-dialog:promotion_actions"
      title="Chess"
      animation-value={@game_state.turn}
      confirmation-dialog-presented={@show_promotion_picker != nil}
      confirmation-dialog-title="Promote this pawn"
      phx-change="promotion-dialog-changed"
    >
      <ToolbarItem placement="principal" template={:toolbar}>
        <Text
          class="px-8 pv-4 font-subheadline foreground-color-white chip-background"
        >
          <%= ElixirconfChess.GameState.description(@game_state) %>
        </Text>
      </ToolbarItem>
      <ToolbarItem placement="primary-action" template={:toolbar}>
        <ShareLink subject="Compete against me in Chess!" item={"elixirconfchess://#{@game_id}"} />
      </ToolbarItem>

      <.player_chip
        game_state={@game_state}
        color={:black}
        turn={@game_state.turn}
        board={@game_state.board}
        format={:swiftui}

        can_add_ai_opponent={@can_add_ai_opponent}
      >
        <%= chip_label(:black, @player_color, @game_state) %>
      </.player_chip>

      <.game_board game_state={@game_state} board={@game_state.board} selection={@selection} turn={@game_state.turn} format={:swiftui} />

      <.player_chip
        game_state={@game_state}
        color={:white}
        turn={@game_state.turn}
        board={@game_state.board}
        format={:swiftui}

        can_add_ai_opponent={@can_add_ai_opponent}
      >
        <%= chip_label(:white, @player_color, @game_state) %>
      </.player_chip>

      <Spacer />

      <Text class="font-headline">Moves</Text>
      <ScrollView axes="horizontal" class="font-subheadline">
        <HStack class="pb-16">
          <Text
            :for={{move, index} <- Enum.with_index(@game_state.move_history)}
            id={"move-#{length(@game_state.move_history) - index}"}
            class="px-4"
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
    <div class="max-w-2xl mx-auto mt-8 px-2">
      <a href="/" class="font-bold">← Back to Lobby</a>
      <div :if={@loading} class="w-full flex flex-col items-center">
        Loading
      </div>
      <div :if={!@loading} class="w-full flex flex-col items-center">
        <div class="py-2 px-4 text-sm font-bold w-fit mx-auto rounded-full text-white" style={"background-color: #{ElixirconfChessWeb.Colors.web(:odd_background)};"}>
          <%= ElixirconfChess.GameState.description(@game_state) %>
        </div>

        <.player_chip
          game_state={@game_state}
          color={:black}
          turn={@game_state.turn}
          board={@game_state.board}
          format={:web}

          can_add_ai_opponent={@can_add_ai_opponent}
        >
          <%= chip_label(:black, @player_color, @game_state) %>
        </.player_chip>

        <.game_board game_state={@game_state} board={@game_state.board} selection={@selection} turn={@game_state.turn} format={:web} />

        <.player_chip
          game_state={@game_state}
          color={:white}
          turn={@game_state.turn}
          board={@game_state.board}
          format={:web}

          can_add_ai_opponent={@can_add_ai_opponent}
        >
          <%= chip_label(:white, @player_color, @game_state) %>
        </.player_chip>

        <p class="opacity-50 w-full text-left mt-4">Moves</p>
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
    </div>
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
                    dbg new_position
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

  def chip_label(color, :spectator, _game_state), do: color |> Atom.to_string() |> String.capitalize()
  def chip_label(chip, color, _game_state) when chip == color, do: "You"
  def chip_label(:white = chip, color, %{ white_is_ai: false }) when chip != color, do: "Opponent"
  def chip_label(:black = chip, color, %{ black_is_ai: false }) when chip != color, do: "Opponent"
  def chip_label(:white = chip, color, %{ white_is_ai: true }) when chip != color, do: "Nx"
  def chip_label(:black = chip, color, %{ black_is_ai: true }) when chip != color, do: "Nx"

  alias ElixirconfChess.GameBoard
  alias ElixirconfChessWeb.Colors

  def game_board(%{format: :swiftui} = assigns) do
    ~SWIFTUI"""
    <%
      moves = case @selection do
        nil ->
          []
        selection ->
          GameBoard.possible_moves(@game_state, selection) |> Enum.map(& &1.destination)
      end
    %>
    <NamespaceContext id={:game_board} class="layout-priority-1">
      <Grid class="aspect-square button-style-plain corner-radius-8" horizontal-spacing={0} vertical-spacing={0}>
        <GridRow :for={y <- GameBoard.y_range}>
          <.tile
            :for={x <- GameBoard.x_range}
            x={x}
            y={y}
            board={@board}
            selection={@selection}
            moves={moves}
            format={:swiftui}
          />
        </GridRow>
      </Grid>
    </NamespaceContext>
    """
  end

  def game_board(%{format: :web} = assigns) do
    ~H"""
    <% moves =
      case @selection do
        nil ->
          []

        selection ->
          GameBoard.possible_moves(@game_state, selection) |> Enum.map(& &1.destination)
      end %>
    <div class="relative max-w-2xl aspect-square w-full rounded-lg overflow-hidden">
      <div class="absolute grid grid-cols-8 grid-rows-8 w-full h-full" style="font-family: Arial;">
        <%
          sorted_pieces = Enum.reduce(@board, [], fn {y, row}, acc -> acc ++ Enum.map(row, fn {x, piece} -> {{x, y}, piece} end) end)
            |> Enum.sort_by(fn {_, {_, _, id}} -> id end)
        %>
        <.tile_piece
          :for={{{x, y}, _} <- sorted_pieces}
          x={x}
          y={y}
          board={@board}
          selection={@selection}
          moves={moves}
          format={:web}
        />
      </div>
      <div class="grid grid-cols-8 grid-rows-8 w-full h-full">
        <%= for y <- GameBoard.y_range do %>
          <.tile :for={x <- GameBoard.x_range()} x={x} y={y} board={@board} selection={@selection} moves={moves} format={:web} />
        <% end %>
      </div>
    </div>
    """
  end

  def tile(%{format: :swiftui} = assigns) do
    ~SWIFTUI"""
    <Button
      phx-click="select"
      phx-value-x={@x}
      phx-value-y={@y}
    >
      <%
        fill = tile_color({@x, @y}) |> Colors.rgba
        overlay = overlay_color(@selection, @moves, {@x, @y}) |> Colors.rgba
      %>
      <Color
        class="overlay:fill overlay:content clipped"
        red={fill.red}
        green={fill.green}
        blue={fill.blue}
        opacity={fill.opacity}
      >
        <Color template={:fill} red={overlay.red} green={overlay.green} blue={overlay.blue} opacity={overlay.opacity} />
        <%
          {color, image, id} = GameBoard.piece(@board, {@x, @y})
          font_size = 50
        %>
        <Text
          template={:content}
          {if id != nil, do: %{ id: to_string(id) }, else: %{ id: "#{@x},#{@y}" }}
          verbatim={image}
          :if={color == :white}
          class="font-largeTitle foreground-color-white matched-geometry-effect:game_board"
        />
        <Text
          template={:content}
          {if id != nil, do: %{ id: to_string(id) }, else: %{ id: "#{@x},#{@y}" }}
          verbatim={image}
          :if={color == :black}
          class="font-largeTitle foreground-color-black matched-geometry-effect:game_board"
        />
      </Color>
    </Button>
    """
  end

  def tile(%{format: :web} = assigns) do
    ~H"""
    <button style={"background-color: #{tile_color({@x, @y}) |> Colors.web};"} class="aspect-square flex overflow-clip" phx-click="select" phx-value-x={@x} phx-value-y={@y}>
      <div class="relative w-full h-full flex justify-center items-center">
        <div class="absolute w-full h-full" style={"background-color: #{overlay_color(@selection, @moves, {@x, @y}) |> Colors.web};"}></div>
      </div>
    </button>
    """
  end

  def tile_piece(%{ format: :web } = assigns) do
    ~H"""
    <%
      {color, image, id} = GameBoard.piece(@board, {@x, @y})
    %>
    <div
      id={to_string(id)}
      style={"left: #{(@x / 8) * 100}%; top: #{(@y / 8) * 100}%; width: 12.5%; height: 12.5%;"}
      class="absolute aspect-square flex overflow-clip transition-all pointer-events-none"
    >
      <div class="relative w-full h-full flex justify-center items-center">
        <p class={"text-5xl text-center z-10 " <> (if color == :white, do: "text-white", else: "text-black")}>
          <%= image %>
        </p>
      </div>
    </div>
    """
  end

  attr :game_state, :any
  attr :color, :any
  attr :turn, :any
  attr :board, :any
  attr :format, :any
  attr :native, :any
  attr :can_add_ai_opponent, :boolean
  slot :inner_block

  def player_chip(%{format: :swiftui, native: %{platform_config: %{user_interface_idiom: "watch"}}} = assigns) do
    ~SWIFTUI"""
    <HStack>
      <%= if @can_add_ai_opponent and Map.get(@game_state, @color) == nil do %>
        <Button
          phx-click="add_ai_opponent"
        >
          <Label system-image="play.desktopcomputer">
            Play against Nx
          </Label>
        </Button>
      <% else %>
        <Text class="font-headline padding"><%= render_slot(@inner_block) %></Text>
      <% end %>
    </HStack>
    """
  end

  def player_chip(%{format: :swiftui} = assigns) do
    ~SWIFTUI"""
    <HStack
      class="pv-8 pl-8 full-width:leading overlay:check_warning fill-attr"
      fill={if @turn == @color, do: "odd_background", else: "even_background"}
    >
      <RoundedRectangle template={:check_warning} corner-radius={8} class="stroke-check" thickness={if GameBoard.in_check?(@game_state, @color), do: 4, else: 0} />

      <Image system-name="person.crop.circle.fill" class="font-largeTitle" />
      <VStack alignment="leading" class="pr-8">
        <Text class="font-headline"><%= render_slot(@inner_block) %></Text>
        <Text class="font-caption"><%= @color |> Atom.to_string() |> String.capitalize() %></Text>
      </VStack>
      <%
        captures = Enum.map(
          GameBoard.captures(@board, @color),
          fn {_, type, id} -> {id, GameBoard.piece(type)} end
        )
      %>
      <ScrollView
        axes="horizontal"
        class="font-largeTitle overlay:ai_opponent"
      >
        <HStack>
          <Text
            :for={{id, image} <- captures}
            id={"#{id}"}
            verbatim={image}
          />
        </HStack>

        <Group template={:ai_opponent}>
          <Button
            :if={@can_add_ai_opponent and Map.get(@game_state, @color) == nil}
            phx-click="add_ai_opponent"
            class="fill-attr"
            fill={if @turn == @color, do: "even_background", else: "odd_background"}
          >
            <Label system-image="play.desktopcomputer">
              Play against Nx
            </Label>
          </Button>
        </Group>
      </ScrollView>
    </HStack>
    """
  end

  def player_chip(%{format: :web} = assigns) do
    ~SWIFTUI"""
    <div class={"w-full flex flex-row my-2 py-2 px-4 rounded-md " <> if(GameBoard.in_check?(@game_state, @color), do: "border-4 border-rose-500", else: "")} style={"background-color: #{Colors.web(if @turn == @color, do: :odd_background, else: :even_background)}"}>
      <div class="flex flex-col">
        <p class="text-md font-bold"><%= render_slot(@inner_block) %></p>
        <p class="text-sm"><%= @color |> Atom.to_string() |> String.capitalize() %></p>
      </div>
      <%
        captures = Enum.map(
          GameBoard.captures(@board, @color),
          fn {_, type, id} -> {id, GameBoard.piece(type)} end
        )
      %>
      <%= if @can_add_ai_opponent and Map.get(@game_state, @color) == nil do %>
        <div class="flex-grow"></div>
        <button
          phx-click="add_ai_opponent"
          class="py-2 px-4 rounded-md font-bold"
          style={"background-color: #{Colors.web(if @turn == @color, do: :even_background, else: :odd_background)}"}
        >
          Play against Nx
        </button>
      <% else %>
        <div class="overflow-x-scroll text-3xl flex-grow">
          <div class="flex flex-row px-4 gap-4">
            <p :for={{id, image} <- captures} id={"#{id}"}>
              <%= image %>
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def tile_color({x, y}) do
    cond do
      rem(x, 2) == rem(y, 2) ->
        :even_background

      true ->
        :odd_background
    end
  end

  def overlay_color(selection, moves, position) do
    cond do
      Enum.member?(moves, position) ->
        :target

      position == selection ->
        :selection

      true ->
        :clear
    end
  end
end
