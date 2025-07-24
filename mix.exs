defmodule Membrane.WebVTT.Plugin.MixProject do
  use Mix.Project

  @github_url "https://github.com/kim-company/membrane_webvtt_format"

  def project do
    [
      app: :membrane_webvtt_plugin,
      version: "1.0.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      source_url: @github_url,
      name: "Membrane WebVTT Plugin",
      deps: deps(),
      description: description(),
      package: package()
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
      {:assert_value, ">= 0.0.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["KIM Keep In Mind"],
      files: ~w(lib mix.exs README.md LICENSE),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @github_url}
    ]
  end

  defp description do
    """
    Membrane WebVTT Plugin for formatting and segmenting WebVTT cues.
    """
  end
end
