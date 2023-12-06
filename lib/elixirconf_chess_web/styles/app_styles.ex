defmodule ElixirconfChessWeb.Styles.AppStyles do
  use LiveViewNative.Stylesheet, :swiftui

  ~SHEET"""
  "layout-priority-" <> priority do
    layoutPriority(to_float(priority))
  end

  "aspect-square" do
    aspectRatio(1, contentMode: .fit)
  end

  "button-style-prominent" do
    buttonStyle(.borderedProminent)
  end

  "button-style-" <> style do
    buttonStyle(to_ime(style))
  end

  "corner-radius-" <> radius do
    clipShape(.rect(cornerRadius: to_float(radius)))
  end

  "foreground-color-" <> color do
    foregroundStyle(to_ime(color))
  end

  "fill-attr" do
    foregroundStyle(attr("fill"))
  end

  "even_background" do
    foregroundStyle(Color(.sRGB, red: 1, green: 0.8, blue: 0.62, opacity: 1))
  end

  "odd_background" do
    foregroundStyle(Color(.sRGB, red: 0.82, green: 0.54, blue: 0.28, opacity: 1))
  end

  "overlay-selection" do
    overlay(Color(.sRGB, red: 0, green: 0, blue: 1, opacity: 0.5))
  end

  "overlay-target" do
    overlay(Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 0.5))
  end

  "overlay-clear" do
    overlay(.clear)
  end

  "overlay:" <> content do
    overlay(content: to_atom(content))
  end

  "clipped" do
    clipped()
  end

  "font-system-" <> size do
    font(.system(size: to_float(size)))
  end

  "font-bold" do
    bold(true)
  end

  "font-" <> style do
    font(to_ime(style))
  end

  "padding" do
    padding(16)
  end

  "p-" <> length do
    padding(to_float(length))
  end

  "px-" <> length do
    padding(.horizontal, to_float(length))
  end

  "py-" <> length do
    padding(.vertical, to_float(length))
  end

  "pl-" <> length do
    padding(.leading, to_float(length))
  end

  "pr-" <> length do
    padding(.trailing, to_float(length))
  end

  "pt-" <> length do
    padding(.top, to_float(length))
  end

  "pb-" <> length do
    padding(.bottom, to_float(length))
  end

  "full-width:" <> alignment do
    frame(maxWidth: .infinity, alignment: to_ime(alignment))
  end

  "stroke-check" do
    strokeBorder(.red, lineWidth: attr("thickness"))
  end

  "navigation-title" do
    navigationTitle(attr("title"))
  end

  "title-inline" do
    navigationBarTitleDisplayMode(.inline)
  end

  "toolbar:" <> content do
    toolbar(content: to_atom(content))
  end

  "animation" do
    animation(.default, value: attr("animation-value"))
  end

  "confirmation-dialog:" <> actions do
    confirmationDialog(
      attr("confirmation-dialog-title"),
      isPresented: attr("confirmation-dialog-presented"),
      titleVisibility: .visible,
      actions: to_atom(actions)
    )
  end

  "image-scale-" <> scale do
    imageScale(to_ime(scale))
  end

  "matched-geometry-effect:" <> namespace do
    matchedGeometryEffect(id: attr("id"), in: namespace)
  end

  "tint-even_background" do
    tint(Color(.sRGB, red: 1, green: 0.8, blue: 0.62, opacity: 1))
  end

  "chip-background" do
    background(Color(.sRGB, red: 0.82, green: 0.54, blue: 0.28, opacity: 1), in: .capsule)
  end
  """

  def class(_, _), do: {:unmatched, []}
end
