defmodule ElixirconfChessWeb.ChessComponents do
  use Phoenix.Component
  use LiveViewNative.Component
  use ElixirconfChessWeb.Styles.AppStyles

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
      class="py-8 pl-8 full-width:leading overlay:check_warning background:fill"
      fill={if @turn == @color, do: "odd_background", else: "even_background"}
    >
      <Color template="fill" red={1} green={0} blue={0} opacity={1} />
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
