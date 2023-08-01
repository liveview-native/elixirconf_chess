defmodule ElixirconfChessWeb.LobbyLive do
  use Phoenix.LiveView
  use LiveViewNative.LiveView

  def mount(%{ "type" => type }, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :join, 3_000) # simulate joining

    {:ok, assign(socket, type: type)}
  end

  def mount(_params, session, socket) do
    mount(%{ "type" => "online" }, session, socket)
  end

  def render(%{ platform_id: :swiftui } = assigns) do
    ~SWIFTUI"""
    <VStack modifiers={navigation_title(title: title(@type))}>
      <ProgressView>Looking for match</ProgressView>
    </VStack>
    """
  end

  def render(assigns) do
    ~H"""
    <progress>
      Looking for match
    </progress>
    """
  end

  def title("online"), do: "Online Match"
  def title("nx"), do: "Nx Match"

  def handle_info(:join, socket) do
    {:noreply, push_navigate(socket, to: "/chess", replace: false)}
  end
end
