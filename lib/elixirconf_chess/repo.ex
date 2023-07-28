defmodule ElixirconfChess.Repo do
  use Ecto.Repo,
    otp_app: :elixirconf_chess,
    adapter: Ecto.Adapters.Postgres
end
