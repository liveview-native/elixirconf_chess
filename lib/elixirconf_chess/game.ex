defmodule ElixirconfChess.Game do
  use GenServer

  alias ElixirconfChess.GameBoard
  alias ElixirconfChess.GameState

  require Logger

  def name(id), do: {:global, {__MODULE__, id}}

  def start_link(_) do
    id = Ecto.UUID.generate()
    GenServer.start_link(__MODULE__, %{id: id}, name: name(id))
  end

  def get_id(server) do
    GenServer.call(server, :get_id)
  end

  def join(id) do
    GenServer.call(name(id), :join)
  end

  def alive?(id) do
    :global.whereis_name({__MODULE__, id}) != :undefined
  end

  def get_game_state(id) do
    GenServer.call(name(id), :get_game_state)
  end

  def move(id, selection, new_position) do
    GenServer.call(name(id), {:move, selection, new_position})
  end

  def init(%{id: id}) do
    Logger.info("Starting game #{id}")
    {:ok, %{id: id, game_state: %GameState{}}}
  end

  def handle_call(:get_id, _, state) do
    {:reply, state.id, state}
  end

  def handle_call(:join, {from, _}, state) do
    game_state = clear_disconnected_players(state.game_state)

    {new_player_color, game_state} =
      case game_state do
        %GameState{white: nil} -> {:white, %GameState{state.game_state | white: from}}
        %GameState{black: nil} -> {:black, %GameState{state.game_state | black: from}}
        _ -> {:spectator, %GameState{state.game_state | spectators: [from | state.game_state.spectators]}}
      end

    Logger.info("Player #{inspect(self())} joined as #{new_player_color}")

    {:reply, {new_player_color, game_state}, %{state | game_state: game_state}}
  end

  def handle_call(:get_game_state, _, state) do
    {:reply, state.game_state, state}
  end

  def handle_call({:move, selection, new_position}, {from, _}, state) do
    case state.game_state do
      %GameState{turn: :white, white: ^from} -> true
      %GameState{turn: :black, black: ^from} -> true
      _ -> false
    end
    |> if do
      board = GameBoard.move(state.game_state.board, selection, new_position)
      game_state_status = GameBoard.game_state(board)
      game_state = %GameState{state.game_state | state: game_state_status, board: board, turn: other_turn(state.game_state.turn)}
      notify_game_state(game_state, from)
      state = %{state | game_state: game_state}
      {:reply, game_state, state}
    else
      {:reply, :not_your_turn, state}
    end
  end

  defp other_turn(:white), do: :black
  defp other_turn(:black), do: :white

  defp notify_game_state(%GameState{} = game_state, except) do
    maybe_notify(game_state, game_state.white, except)
    maybe_notify(game_state, game_state.black, except)
    Enum.map(game_state.spectators, &maybe_notify(game_state, &1, except))
  end

  defp maybe_notify(_game_state, nil, _pid), do: nil
  defp maybe_notify(_game_state, pid, pid), do: nil
  defp maybe_notify(game_state, pid, _other_pid), do: send(pid, {:game_state_update, game_state})

  defp clear_disconnected_players(%GameState{white: wp, black: bp} = game_state) do
    game_state =
      if wp != nil && !Process.alive?(wp) do
        Logger.info("white disconnected, removing")
        %GameState{game_state | white: nil}
      else
        game_state
      end

    if bp != nil && !Process.alive?(bp) do
      Logger.info("black disconnected, removing")
      %GameState{game_state | black: nil}
    else
      game_state
    end
  end
end
