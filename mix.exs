defmodule HTTPSignals.MixProject do
  use Mix.Project

  def project do
    [
      app: :http_signals,
      description:
        "Intercepting Req requests and storing the data (response and request) in your database.",
      package: %{
        links: %{"GitHub" => "https://github.com/krainboltgreene/http_signals.ex"},
        licenses: ["LicenseRef-Hippocratic-3.0-core"]
      },
      version: "1.0.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
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

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.7.0", optional: true},
      {:phoenix, "~> 1.0", optional: true},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.2"},
      {:gettext, "~> 1.0"},
      {:ecto_sql, "~> 3.10", optional: true},
      {:ecto_sqlite3, "~> 0.26.0", only: [:docs, :dev, :test]},
      {:postgrex, "~> 0.22.2", optional: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:machete, "~> 0.3.1", only: :test},
      {:ex_doc, "~> 0.40", only: [:docs, :dev]},
      {:mdex, "~> 0.12", only: [:docs, :dev]},
      {:inch_ex, "~> 2.0", only: [:dev, :test]}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
