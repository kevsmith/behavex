defmodule Behavex.MixProject do
  use Mix.Project

  def project do
    [
      app: :behavex,
      version: "0.1.0",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [long_compilation_threshold: 2, warnings_as_errors: true],
      test_coverage: test_coverage(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [flags: ["-Wunmatched_returns", :error_handling, :overspecs]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:crypto, :sasl, :logger],
      mod: {Behavex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_uuid, "~> 1.2.0"},

      # Dev deps
      {:dialyxir, "~> 1.1.0", only: [:dev, :test], runtime: false},

      # Testing deps
      {:mox, "~> 1.0.0", only: [:test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_coverage() do
    [
      ignore_modules: [
        # Skip boilerplate modules
        Behavex.Application,
        Behavex.InitArgs,
        Behavex.Operation.UnknownStatusError,
        # Skip modules in test/support
        Behavex.CountOperation,
        Behavex.EvenOperation,
        Behavex.StaticOperation,
        Behavex.ConfigurableOperation
      ],
      summary: [threshold: 80]
    ]
  end
end
