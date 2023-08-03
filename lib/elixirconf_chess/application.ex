defmodule ElixirconfChess.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ElixirconfChessWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: ElixirconfChess.PubSub},
      ElixirconfChess.GameMaster,
      # Start the Endpoint (http/https)
      ElixirconfChessWeb.Endpoint
      # Start a worker by calling: ElixirconfChess.Worker.start_link(arg)
      # {ElixirconfChess.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirconfChess.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixirconfChessWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
