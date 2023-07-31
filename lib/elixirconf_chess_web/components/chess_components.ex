defmodule ElixirconfChessWeb.ChessComponents do
  use Phoenix.Component
  use LiveViewNative.Component

  alias ElixirconfChess.GameBoard

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
      <Grid modifiers={animation(animation: :default, value: Atom.to_string(@turn)) |> aspect_ratio(1, content_mode: :fit) |> button_style(style: :plain)} horizontal-spacing={0} vertical-spacing={0}>
        <GridRow :for={y <- GameBoard.y_range}>
          <Button
            :for={x <- GameBoard.x_range}
            phx-click="select"
            phx-value-x={x}
            phx-value-y={y}
          >
            <Rectangle
              modifiers={
                foreground_style(tile_color({x, y}))
                  |> overlay(style: overlay_color(@selection, moves, {x, y}))
                  |> overlay(content: :content)
                  |> clipped([])
              }
            >
              <%!-- <Text template={:content} modifiers={foreground_style({:color, :secondary}) |> bold([])}><%= GameBoard.format_position({x, y}) %></Text> --%>
              <%
                {color, image, id} = GameBoard.piece(@board, {x, y})
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
    <div class="grid grid-cols-8 grid-rows-8 max-w-2xl w-full aspect-square">
      <%= for y <- GameBoard.y_range do %>
        <button
          :for={x <- GameBoard.x_range}
          style={"background-color: #{css_color(tile_color({x, y}))};"}
          class="aspect-square flex overflow-clip"
          phx-click="select"
          phx-value-x={x}
          phx-value-y={y}
        >
          <%
            {color, image, _} = GameBoard.piece(@board, {x, y})
          %>
          <div class="relative w-full h-full flex justify-center items-center">
            <div class="absolute w-full h-full" style={"background-color: #{css_color(overlay_color(@selection, moves, {x, y}))};"}></div>
            <p class={"text-5xl text-center " <> (if color == :white, do: "text-white", else: "text-black")}>
              <%= image %>
            </p>
          </div>
        </button>
      <% end %>
    </div>
    """
  end

  def tile_color({x, y}) do
    cond do
      rem(x, 2) != rem(y, 2) ->
        {:color, {:srgb, %{ red: 1, green: 0.8, blue: 0.62 }}}
      true ->
        {:color, {:srgb, %{ red: 0.82, green: 0.54, blue: 0.28 }}}
    end
  end

  def overlay_color(selection, moves, position) do
    cond do
      Enum.member?(moves, position) ->
        {:color, :red, [{:opacity, 0.5}]}
      position == selection ->
        {:color, :blue, [{:opacity, 0.5}]}
      true ->
        {:color, :white, [{:opacity, 0}]}
    end
  end

  def css_color({:color, {:srgb, %{ red: red, green: green, blue: blue }}}), do: "rgb(#{red * 255}, #{green * 255}, #{blue * 255})"
  def css_color({:color, :red, [opacity: 0.5]}), do: "rgba(255, 0, 0, 0.5)"
  def css_color({:color, :blue, [opacity: 0.5]}), do: "rgba(0, 0, 255, 0.5)"
  def css_color({:color, :white, [opacity: 0]}), do: "rgba(0, 0, 0, 0)"
end
