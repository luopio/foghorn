defmodule Foghorn.Mixfile do
  use Mix.Project

  def project do
    [app: :foghorn,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     escript: [main_module: Foghorn]
     ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications: [:logger, :postgrex, :cowboy, :ranch, :poison],
      mod: {Foghorn, []}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:cowboy, "1.0.0" },
      {:postgrex, "~> 0.11.1"},
      {:poison, "~> 2.0"},
      {:exrm, "~> 1.0.5"}
    ]
  end
end
