defmodule Reelmagic.MixProject do
  use Mix.Project

  def project do
    [
      app: :reelmagic,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: Reelmagic.CLI, name: "reelmagic_dl.ex"]
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
      {:httpoison, "~> 1.5"},
      {:jason, "~> 1.1"},
      {:porcelain, "~> 2.0"}
    ]
  end
end
