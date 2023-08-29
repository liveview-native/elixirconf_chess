defmodule ElixirconfChessWeb.PageController do
  use ElixirconfChessWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def privacy(conn, _params) do
    html(conn, File.read!("lib/elixirconf_chess_web/controllers/page_html/privacy.html"))
  end
end
