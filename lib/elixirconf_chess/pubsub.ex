defmodule ElixirconfChess.PubSub do
  alias Phoenix.PubSub

  def subscribe_lobby do
    PubSub.subscribe(ElixirconfChess.PubSub, "lobby")
  end

  def broadcast_lobby(games) do
    PubSub.broadcast(ElixirconfChess.PubSub, "lobby", {:lobby_update, games})
  end
end
