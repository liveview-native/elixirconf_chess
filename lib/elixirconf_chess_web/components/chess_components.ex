defmodule ElixirconfChessWeb.ChessComponents do
  use Phoenix.Component
  use LiveViewNative.Component

  alias ElixirconfChess.GameBoard
  alias ElixirconfChessWeb.Colors

  def game_board(%{platform_id: :swiftui} = assigns) do
    ~SWIFTUI"""
    <%
      moves = case @selection do
        nil ->
          []
        selection ->
          GameBoard.possible_moves(@game_state, selection) |> Enum.map(& &1.destination)
      end
    %>
    <NamespaceContext id={:game_board} modifiers={layout_priority(1)}>
      <Grid modifiers={aspect_ratio(1, content_mode: :fit) |> button_style(:plain) |> corner_radius(8)} horizontal-spacing={0} vertical-spacing={0}>
        <GridRow :for={y <- GameBoard.y_range}>
          <.tile
            :for={x <- GameBoard.x_range}
            x={x}
            y={y}
            board={@board}
            selection={@selection}
            moves={moves}
            native={@native}
            platform_id={:swiftui}
          />
        </GridRow>
      </Grid>
    </NamespaceContext>
    """
  end

  def game_board(%{platform_id: :web} = assigns) do
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
          native={@native}
          platform_id={:web}
        />
      </div>
      <div class="grid grid-cols-8 grid-rows-8 w-full h-full">
        <%= for y <- GameBoard.y_range do %>
          <.tile :for={x <- GameBoard.x_range()} x={x} y={y} board={@board} selection={@selection} moves={moves} native={@native} platform_id={:web} />
        <% end %>
      </div>
    </div>
    """
  end

  def tile(%{platform_id: :swiftui} = assigns) do
    ~SWIFTUI"""
    <Button
      phx-click="select"
      phx-value-x={@x}
      phx-value-y={@y}
    >
      <Rectangle
        modifiers={
          foreground_style(tile_color({@x, @y}) |> Colors.swiftui)
            |> overlay(style: overlay_color(@selection, @moves, {@x, @y}) |> Colors.swiftui)
            |> overlay(content: :content)
            |> clipped([])
        }
      >
        <%
          {color, image, id} = GameBoard.piece(@board, {@x, @y})
          font_size = if @native.platform_config.user_interface_idiom == "watch", do: 17, else: 50
          piece_modifiers = font(font: {:system, [size: font_size]}) |> foreground_style({:color, color})
        %>
        <Text
          template={:content}
          {if id != nil, do: %{ id: to_string(id) }, else: %{}}
          verbatim={image}
          modifiers={
            if id != nil, do: piece_modifiers |> matched_geometry_effect(id: to_string(id), namespace: :game_board), else: piece_modifiers
          } />
      </Rectangle>
    </Button>
    """
  end

  def tile(%{platform_id: :web} = assigns) do
    ~H"""
    <button style={"background-color: #{tile_color({@x, @y}) |> Colors.web};"} class="aspect-square flex overflow-clip" phx-click="select" phx-value-x={@x} phx-value-y={@y}>
      <div class="relative w-full h-full flex justify-center items-center">
        <div class="absolute w-full h-full" style={"background-color: #{overlay_color(@selection, @moves, {@x, @y}) |> Colors.web};"}></div>
      </div>
    </button>
    """
  end

  def tile_piece(%{ platform_id: :web } = assigns) do
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
  attr :platform_id, :any
  attr :native, :any
  attr :can_add_ai_opponent, :boolean
  slot :inner_block

  def player_chip(%{platform_id: :swiftui, native: %{platform_config: %{user_interface_idiom: "watch"}}} = assigns) do
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
        <Text modifiers={font({:system, :headline}) |> padding()}><%= render_slot(@inner_block) %></Text>
      <% end %>
    </HStack>
    """
  end

  def player_chip(%{platform_id: :swiftui} = assigns) do
    ~SWIFTUI"""
    <HStack
      modifiers={
        padding([top: 8, bottom: 8, leading: 8])
          |> frame(max_width: 9999999999, alignment: :leading)
          |> overlay(content: :check_warning)
          |> background({:color, Colors.swiftui(if @turn == @color, do: :odd_background, else: :even_background) |> elem(1)}, in: {:rounded_rectangle, radius: 8})
          |> foreground_style({:color, @color})
        }
    >
      <RoundedRectangle template={:check_warning} corner-radius={8} modifiers={stroke_border(content: {:color, :red}, style: [line_width: (if GameBoard.in_check?(@game_state, @color), do: 4, else: 0)])} />

      <Image system-name="person.crop.circle.fill" modifiers={font({:system, :large_title})} />
      <VStack alignment="leading" modifiers={padding(:trailing, 8)}>
        <Text modifiers={font({:system, :headline, [weight: :bold]})}><%= render_slot(@inner_block) %></Text>
        <Text modifiers={font({:system, :caption})}><%= @color |> Atom.to_string() |> String.capitalize() %></Text>
      </VStack>
      <%
        captures = Enum.map(
          GameBoard.captures(@board, @color),
          fn {_, type, id} -> {id, GameBoard.piece(type)} end
        )
      %>
      <ScrollView
        axes="horizontal"
        modifiers={
          font({:system, :large_title})
          |> foreground_style({:color, GameBoard.enemy(@color)})
          |> overlay(alignment: :trailing, content: :ai_opponent)
        }
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
            modifiers={
              padding(8)
              |> background(Colors.swiftui(if @turn == @color, do: :even_background, else: :odd_background), in: {:rounded_rectangle, radius: 6})
              |> padding(:trailing, 8)
            }
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

  def player_chip(%{platform_id: :web} = assigns) do
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
