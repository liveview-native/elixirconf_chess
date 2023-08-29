defmodule ElixirconfChess.Game do
  use GenServer

  alias ElixirconfChess.GameBoard
  alias ElixirconfChess.GameState
  alias ElixirconfChess.PubSub

  require Logger

  def name(id), do: {:global, {__MODULE__, id}}

  def start_link(_) do
    id = Ecto.UUID.generate()
    GenServer.start_link(__MODULE__, %{id: id}, name: name(id))
  end

  def get_id(server) do
    GenServer.call(server, :get_id)
  end

  def join(id, is_ai) do
    GenServer.call(name(id), {:join, is_ai})
  end

  def alive?(id) do
    :global.whereis_name({__MODULE__, id}) != :undefined
  end

  def get_game_state(id) do
    GenServer.call(name(id), :get_game_state)
  end

  def move(id, selection, new_position, promotion_type) do
    GenServer.call(name(id), {:move, selection, new_position, promotion_type})
  end

  def init(%{id: id}) do
    Logger.info("Starting game #{id}")
    ai_tick()
    {:ok, %{id: id, game_state: %GameState{}}}
  end

  def handle_info(:ai_tick, %{game_state: %GameState{state: {:checkmate, _}}} = state), do: {:noreply, state}
  def handle_info(:ai_tick, %{game_state: %GameState{state: {:checkmate, _}}} = state), do: {:noreply, state}

  def handle_info(:ai_tick, state) do
    {_eval, move} =
      case state.game_state do
        %{turn: :black, black_is_ai: true, state: {:active, _}} ->
          ElixirconfChess.AI.choose_move(state.game_state, :black)

        %{turn: :white, white_is_ai: true, state: {:active, _}} ->
          ElixirconfChess.AI.choose_move(state.game_state, :white)

        _ ->
          {0, nil}
      end

    state =
      case move do
        %{source: source, destination: destination} ->
          state = update_game_with_move(state, source, destination, :queen)
          PubSub.broadcast_game(state.id, state.game_state)
          state

        _ ->
          state
      end

    case state.game_state.state do
      {:active, _} ->
        ai_tick()

      _ ->
        nil
    end

    {:noreply, state}
  end

  def handle_call(:get_id, _, state) do
    {:reply, state.id, state}
  end

  def handle_call({:join, is_ai}, {from, _}, state) do
    game_state = clear_disconnected_players(state.game_state)

    pid =
      if is_ai do
        loop = fn f -> f.(f) end
        spawn_link(fn -> loop.(loop) end)
      else
        from
      end

    {new_player_color, game_state} =
      case game_state do
        %GameState{white: nil} -> {:white, %GameState{state.game_state | white: pid, white_is_ai: is_ai}}
        %GameState{black: nil} -> {:black, %GameState{state.game_state | black: pid, black_is_ai: is_ai}}
        _ -> {:spectator, %GameState{state.game_state | spectators: [from | state.game_state.spectators]}}
      end

    Logger.info("Player #{inspect(self())} joined as #{new_player_color}")

    {:reply, {new_player_color, game_state}, %{state | game_state: game_state}}
  end

  def handle_call(:get_game_state, _, state) do
    {:reply, state.game_state, state}
  end

  def handle_call({:move, selection, new_position, promotion_type}, {from, _}, state) do
    case state.game_state do
      %GameState{turn: :white, white: ^from} -> true
      %GameState{turn: :black, black: ^from} -> true
      _ -> false
    end
    |> if do
      state = update_game_with_move(state, selection, new_position, promotion_type)
      PubSub.broadcast_game(state.id, state.game_state)
      {:reply, :ok, state}
    else
      {:reply, :not_your_turn, state}
    end
  end

  defp update_game_with_move(state, selection, new_position, promotion_type) do
    board = GameBoard.move(state.game_state, selection, new_position, promotion_type)
    game_state = %GameState{state.game_state | board: board}
    game_state_status = GameBoard.game_state(game_state)

    move_history = [GameBoard.Move.new(state.game_state, selection, new_position, true) | game_state.move_history]
    game_state = %GameState{game_state | state: game_state_status, turn: other_turn(game_state.turn), move_history: move_history}
    %{state | game_state: game_state}
  end

  defp other_turn(:white), do: :black
  defp other_turn(:black), do: :white

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

  defp ai_tick, do: Process.send_after(self(), :ai_tick, 200)
end
