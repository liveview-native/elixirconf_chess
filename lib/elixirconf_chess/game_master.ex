defmodule ElixirconfChess.GameMaster do
  use GenServer

  alias ElixirconfChess.Game

  require Logger

  def name, do: {:global, __MODULE__}

  def start_link(_) do
    case GenServer.start_link(__MODULE__, :ok, name: name()) do
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  def list_games do
    GenServer.call(name(), :list_games)
  end

  def create_game do
    GenServer.call(name(), :create_game)
  end

  def init(:ok) do
    Logger.info("Starting #{__MODULE__}")
    {:ok, %{games: %{}}}
  end

  def handle_call(:list_games, _, state) do
    {:reply, state.games, state}
  end

  def handle_call(:create_game, _, state) do
    {:ok, pid} = Game.start_link(:ok)
    id = Game.get_id(pid)
    game_state = Game.get_game_state(id)
    state = %{state | games: Map.put(state.games, id, game_state)}
    ElixirconfChess.PubSub.broadcast_lobby(state.games)
    {:reply, id, state}
  end
end
