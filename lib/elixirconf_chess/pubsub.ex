defmodule ElixirconfChess.PubSub do
  alias ElixirconfChess.GameState
  alias Phoenix.PubSub

  def subscribe_lobby do
    PubSub.subscribe(ElixirconfChess.PubSub, "lobby")
  end

  def subscribe_game(id) do
    PubSub.subscribe(ElixirconfChess.PubSub, "game:#{id}")
  end

  def broadcast_game(id, %GameState{} = game_state) do
    PubSub.broadcast(ElixirconfChess.PubSub, "lobby", {:game_update, id, game_state})
    PubSub.broadcast(ElixirconfChess.PubSub, "game:#{id}", {:game_update, id, game_state})
  end
end
