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

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:benchee, ">=0.0.0", only: [:dev]},
      {:jason, ">=0.0.0", only: [:dev]},
      {:poison, ">=0.0.0", only: [:dev]},
      {:decimal, ">=0.0.0", only: [:dev, :test]},
      {:data_schema, ">=0.0.0", only: [:dev, :test]}
    ]
  end
end
