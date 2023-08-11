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

  def move(id, selection, new_position) do
    GenServer.call(name(id), {:move, selection, new_position})
  end

  def init(%{id: id}) do
    Logger.info("Starting game #{id}")
    ai_tick()
    {:ok, %{id: id, game_state: %GameState{}}}
  end

  def handle_info(:ai_tick, state) do
    # IO.inspect(state, label: "ai_tick state")

    move =
      case state.game_state do
        %{turn: :black, black_is_ai: true} ->
          ElixirconfChess.AI.choose_move(state.game_state.board, :black)

        %{turn: :white, white_is_ai: true} ->
          ElixirconfChess.AI.choose_move(state.game_state.board, :white)

        _ ->
          nil
      end

    IO.inspect({move, state.game_state.turn}, label: "move, turn")

    state =
      case move do
        %{source: source, destination: destination} ->
          state = update_game_with_move(state, source, destination)
          PubSub.broadcast_game(state.id, state.game_state)
          state

        _ ->
          state
      end

    ai_tick()
    {:noreply, state}
  end

  def handle_call(:get_id, _, state) do
    {:reply, state.id, state}
  end

  def handle_call({:join, is_ai}, {from, _}, state) do
    game_state = clear_disconnected_players(state.game_state)

    {new_player_color, game_state} =
      case game_state do
        %GameState{white: nil} -> {:white, %GameState{state.game_state | white: from, white_is_ai: is_ai}}
        %GameState{black: nil} -> {:black, %GameState{state.game_state | black: from, black_is_ai: is_ai}}
        _ -> {:spectator, %GameState{state.game_state | spectators: [from | state.game_state.spectators]}}
      end

    IO.inspect(game_state, label: "state after join")

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
      state = update_game_with_move(state, selection, new_position)
      PubSub.broadcast_game(state.id, state.game_state)
      {:reply, :ok, state}
    else
      {:reply, :not_your_turn, state}
    end
  end

  defp update_game_with_move(state, selection, new_position) do
    board = GameBoard.move(state.game_state.board, selection, new_position)
    game_state_status = GameBoard.game_state(board)
    move_history = [ElixirconfChess.AlgebraicNotation.move_algebra(state.game_state.board, board, selection, new_position) | state.game_state.move_history]
    game_state = %GameState{state.game_state | state: game_state_status, board: board, turn: other_turn(state.game_state.turn), move_history: move_history}
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

  defp ai_tick, do: Process.send_after(self(), :ai_tick, 1_000)
end
