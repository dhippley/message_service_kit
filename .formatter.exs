# Used by "mix format"
[
  inputs: ["mix.exs", "{config,apps}/**/*.{ex,exs,heex}"],
  import_deps: [:ecto, :phoenix],
  plugins: [Styler, Phoenix.LiveView.HTMLFormatter]

]
