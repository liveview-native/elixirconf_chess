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
      <Grid modifiers={aspect_ratio(1, content_mode: :fit) |> animation(animation: :default, value: Atom.to_string(@turn))} horizontal-spacing={0} vertical-spacing={0}>
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
              }
            >
              <%!-- <Text template={:content} modifiers={foreground_style({:color, :secondary}) |> bold([])}><%= GameBoard.format_position({x, y}) %></Text> --%>
              <%
                {color, image, id} = GameBoard.piece(@board, {x, y})
                piece_modifiers = font(font: {:system, [size: 50]}) |> foreground_style({:color, color})
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
end
