defmodule StatementsReader.MixProject do
  use Mix.Project

  def project do
    [
      app: :statements_reader,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      escript: escript(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {StatementsReader.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:jason, "~> 1.2"}, {:elixlsx, "~> 0.4.2"}]
  end

  # Run "mix help escript" to learn about escript.
  defp escript do
    [main_module: StatementsReader.CLI, name: :xpesa_parser]
  end
end
