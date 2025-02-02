defmodule MembraneWebvttPlugin.MixProject do
  use Mix.Project

  def project do
    [
      app: :membrane_webvtt_plugin,
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
      {:membrane_core, "~> 1.1"},
      {:membrane_text_format, "~> 1.0"},
      {:kim_subtitle, "~> 0.1"},
      {:assert_value, ">= 0.0.0", only: [:dev, :test]}
    ]
  end
end
