defmodule Foghorn.Mixfile do
  use Mix.Project

  def project do
    [
      app: :foghorn,
      version: "2.4.2",
      elixir: "> 1.6.5",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      escript: [main_module: Foghorn]
    ]
  end

  def application do
    [
      applications: [
        :logger,
        :postgrex,
        :cowboy,
        :ranch,
        :poison,
        :yaml_elixir
      ],
      mod: {Foghorn, []}
    ]
  end

  defp deps do
    [
      {:cowboy, "2.7.0" },
      {:postgrex, "~> 0.15.4"},
      {:poison, "~> 4.0"},
      {:yaml_elixir, "~> 2.4.0"},
      {:socket, "~> 0.3", runtime: false},
    ]
  end
end
