defmodule ElixirconfChessWeb.IndexLive do
  use Phoenix.LiveView
  use LiveViewNative.LiveView

  alias ElixirconfChess.GameMaster

  def mount(_params, _session, socket) do
    ElixirconfChess.PubSub.subscribe_lobby()
    {:ok, assign(socket, :games, GameMaster.list_games())}
  end

  def render(%{platform_id: :swiftui} = assigns) do
    ~SWIFTUI"""
    <VStack modifiers={navigation_title(title: "Chess") |> button_style(style: :bordered_prominent) |> padding([])}>
      <.play_button type="online" color={:odd_background} foreground={:white} image="network">
        Online Match
      </.play_button>
      <.play_button type="nx" color={:even_background} foreground={:black} image="point.3.filled.connected.trianglepath.dotted">
        Nx Match
      </.play_button>
      <Spacer />
    </VStack>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="w-full flex flex-col items-center gap-2">
      <p class="text-5xl font-bold">Chess</p>
      <%= for {game_id, index} <- Enum.with_index(Map.keys(@games)) do %>
        <button phx-click="join" phx-value-id={game_id} style={"background-color: #{background_color(index)};"} class="p-2 font-bold text-white rounded">
          Join Game
        </button>
      <% end %>
      <button phx-click="create" style={"background-color: #{background_color(map_size(@games))};"} class="p-2 font-bold rounded">
        Create Game
      </button>
    </div>
    """
  end

  attr :type, :string
  attr :color, :any
  attr :foreground, :any
  attr :image, :string
  slot :inner_block

  def play_button(assigns) do
    ~SWIFTUI"""
    <Button
        phx-click="play"
        phx-value-type={@type}
        modifiers={tint(color: ElixirconfChessWeb.Colors.swiftui(@color) |> elem(1)) |> foreground_style({:color, @foreground})}
      >
        <Label system-image={@image} modifiers={frame(max_width: 99999) |> padding(8) |> font(font: {:system, :headline})}>
          <%= render_slot(@inner_block) %>
        </Label>
    </Button>
    """
  end

  def handle_event("join", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: "/game/#{id}", replace: false)}
  end

  def handle_event("create", _, socket) do
    game_id = GameMaster.create_game()
    {:noreply, push_navigate(socket, to: "/game/#{game_id}", replace: false)}
  end

  def background_color(index) when rem(index, 2) == 0, do: ElixirconfChessWeb.Colors.web(:odd_background)
  def background_color(_index), do: ElixirconfChessWeb.Colors.web(:even_background)

  def handle_info({:lobby_update, games}, socket) do
    {:noreply, assign(socket, :games, games)}
  end
end
