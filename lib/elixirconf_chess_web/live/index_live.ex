defmodule ElixirconfChessWeb.IndexLive do
  use Phoenix.LiveView
  use LiveViewNative.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(%{ platform_id: :swiftui } = assigns) do
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
      <button phx-click="play" phx-value-type="online" style={"background-color: #{ElixirconfChessWeb.Colors.web(:odd_background)};"} class="p-2 font-bold text-white rounded">
        Online Match
      </button>
      <button phx-click="play" phx-value-type="nx" style={"background-color: #{ElixirconfChessWeb.Colors.web(:even_background)};"} class="p-2 font-bold rounded">
        Nx Match
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

  def handle_event("play", %{ "type" => type }, socket) do
    {:noreply, push_navigate(socket, to: "/lobby?type=#{type}", replace: false)}
  end
end
