defmodule Behavex.MixProject do
  use Mix.Project

  def project do
    [
      app: :behavex,
      version: "0.1.0",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: test_coverage(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:shortuuid, "~> 2.1.0"},

      # Testing deps
      {:mox, "~> 1.0.0", only: [:test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_coverage() do
    [
      ignore_modules: [
        # Skip modules in test/support
        Behavex.CountingOperation,
        Behavex.ErrorOperation,
        Behavex.FailureOperation,
        Behavex.OperationCase,
        Behavex.OperationStatusMismatch,
        Inspect.Behavex.Operation
      ]
    ]
  end
end
