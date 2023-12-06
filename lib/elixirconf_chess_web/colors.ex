defmodule ElixirconfChessWeb.Colors do
  def rgba(:even_background), do: %{red: 1, green: 0.8, blue: 0.62, opacity: 1}
  def rgba(:odd_background), do: %{red: 0.82, green: 0.54, blue: 0.28, opacity: 1}

  def rgba(:selection), do: %{red: 0, green: 0, blue: 1, opacity: 0.5}
  def rgba(:target), do: %{red: 1, green: 0, blue: 0, opacity: 0.5}
  def rgba(:clear), do: %{red: 1, green: 1, blue: 1, opacity: 0}

  def swiftui(color) do
    color |> Atom.to_string
  end

  def web(color) do
    %{red: red, green: green, blue: blue, opacity: opacity} = rgba(color)
    "rgba(#{red * 255}, #{green * 255}, #{blue * 255}, #{opacity})"
  end

  def evaluate(color, :swiftui), do: swiftui(color)
  def evaluate(color, :web), do: web(color)
end
