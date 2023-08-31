defmodule ElixirconfChessWeb.IndexLive do
  use Phoenix.LiveView
  use LiveViewNative.LiveView

  alias ElixirconfChess.GameState
  alias ElixirconfChess.GameMaster

  def mount(_params, _session, socket) do
    ElixirconfChess.PubSub.subscribe_lobby()
    {:ok, assign(socket, :games, GameMaster.list_games())}
  end

  def render(%{platform_id: :swiftui} = assigns) do
    ~SWIFTUI"""
    <OpenGameListener />
    <ScrollView modifiers={navigation_title(title: "Lobby") |> toolbar(content: :toolbar)}>
      <Group template={:toolbar}>
        <ToolbarItem>
          <Button phx-click="create">
            <Label system-image="plus.square.on.square">
              Create Game
            </Label>
          </Button>
        </ToolbarItem>
      </Group>
      <LazyVStack modifiers={button_style(:bordered_prominent) |> padding()}>
        <%= for {game_id, index} <- Enum.with_index(Map.keys(@games)) do %>
          <.play_button phx-click="join" phx-value-id={game_id} color={background_color(index, :swiftui)} foreground={button_foreground(index, :swiftui)} image="play.square.fill">
            <VStack alignment="leading" modifiers={frame(max_width: 99999999, alignment: :leading)}>
              <Text>Join Game</Text>
              <Text modifiers={font({:system, :subheadline}) |> foreground_style({:hierarchical, :secondary})}>
                <%= String.slice(game_id, 0..3) |> String.upcase() %>
              </Text>
            </VStack>
          </.play_button>
        <% end %>
      </LazyVStack>
    </ScrollView>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto flex flex-col items-center gap-2 px-2">
      <p class="text-5xl font-bold my-4">Chess</p>
      <button phx-click="create" style={"background-color: #{background_color(-1, :web)};"} class="p-2 font-bold rounded w-full">
        ＋ Create Game
      </button>
      <hr class="border w-full my-4" />
      <%= for {game_id, index} <- Enum.with_index(Map.keys(@games)) do %>
        <button phx-click="join" phx-value-id={game_id} phx-value-ai={:player} style={"background-color: #{background_color(index, :web)};"} class="p-2 text-white rounded w-full text-left flex flex-row gap-2">
          <p>▶</p>
          <div class="flex flex-col">
            <p class="font-bold">Join Game</p>
            <p class="text-sm opacity-50">
              <%= String.slice(game_id, 0..3) |> String.upcase() %>
            </p>
          </div>
        </button>
      <% end %>
    </div>
    """
  end

  attr :type, :string
  attr :color, :any
  attr :foreground, :any
  attr :image, :string
  attr :rest, :global
  slot :inner_block

  def play_button(assigns) do
    ~SWIFTUI"""
    <Button
        {@rest}
        modifiers={tint(color: @color |> elem(1)) |> foreground_style({:color, @foreground})}
      >
        <Label system-image={@image} modifiers={frame(max_width: 99999) |> padding(8) |> font({:system, :headline}) |> image_scale(:large)}>
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

  def background_color(index, platform) when rem(index, 2) == 0, do: ElixirconfChessWeb.Colors.evaluate(:odd_background, platform)
  def background_color(_index, platform), do: ElixirconfChessWeb.Colors.evaluate(:even_background, platform)

  def button_foreground(index, _platform) when rem(index, 2) == 0, do: :white
  def button_foreground(_index, _platform), do: :black

  def handle_info({:game_update, id, %GameState{state: {:active, _}} = game}, socket) do
    {:noreply, assign(socket, :games, Map.put(socket.assigns.games, id, game))}
  end

  def handle_info({:game_update, id, %GameState{}}, socket) do
    {:noreply, assign(socket, :games, Map.delete(socket.assigns.games, id))}
  end
end
