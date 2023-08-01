defmodule ElixirconfChessWeb.ChessComponents do
  use Phoenix.Component
  use LiveViewNative.Component

  alias ElixirconfChess.GameBoard
  alias ElixirconfChessWeb.Colors

  def game_board(%{ platform_id: :swiftui } = assigns) do
    ~SWIFTUI"""
    <%
      moves = case @selection do
        nil ->
          []
        selection ->
          GameBoard.possible_moves(@board, selection)
      end
    %>
    <NamespaceContext id={:game_board}>
      <Grid modifiers={animation(animation: :default, value: Atom.to_string(@turn)) |> aspect_ratio(1, content_mode: :fit) |> button_style(style: :plain) |> corner_radius(radius: 8)} horizontal-spacing={0} vertical-spacing={0}>
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

  def game_board(%{ platform_id: :web } = assigns) do
    ~H"""
    <%
      moves = case @selection do
        nil ->
          []
        selection ->
          GameBoard.possible_moves(@board, selection)
      end
    %>
    <div class="grid grid-cols-8 grid-rows-8 max-w-2xl w-full aspect-square rounded-lg overflow-hidden">
      <%= for y <- GameBoard.y_range do %>
        <.tile
          :for={x <- GameBoard.x_range}
          x={x}
          y={y}
          board={@board}
          selection={@selection}
          moves={moves}
          native={@native}
          platform_id={:web}
        />
      <% end %>
    </div>
    """
  end

  def tile(%{ platform_id: :swiftui } = assigns) do
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

  def tile(%{ platform_id: :web } = assigns) do
    ~H"""
    <button
      style={"background-color: #{tile_color({@x, @y}) |> Colors.web};"}
      class="aspect-square flex overflow-clip"
      phx-click="select"
      phx-value-x={@x}
      phx-value-y={@y}
    >
      <%
        {color, image, _} = GameBoard.piece(@board, {@x, @y})
      %>
      <div class="relative w-full h-full flex justify-center items-center">
        <div class="absolute w-full h-full" style={"background-color: #{overlay_color(@selection, @moves, {@x, @y}) |> Colors.web};"}></div>
        <p class={"text-5xl text-center z-10 " <> (if color == :white, do: "text-white", else: "text-black")}>
          <%= image %>
        </p>
      </div>
    </button>
    """
  end

  def tile_color({x, y}) do
    cond do
      rem(x, 2) != rem(y, 2) ->
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
