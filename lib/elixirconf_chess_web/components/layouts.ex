defmodule ElixirconfChessWeb.Layouts do
  use ElixirconfChessWeb, :html
  use LiveViewNative.Layouts

  embed_templates "layouts/*.html"
end
