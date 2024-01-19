defmodule Jxon.MixProject do
  use Mix.Project

  def project do
    [
      app: :jxon,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      {:benchee, ">=0.0.0", only: [:dev]},
      {:jason, ">=0.0.0", only: [:dev]},
      {:poison, ">=0.0.0", only: [:dev]}
    ]
  end
end
