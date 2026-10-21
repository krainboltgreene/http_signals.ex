# General application configuration
import Config

config :http_signals,
  repo: HTTPSignals.TestRepo

config :http_signals, HTTPSignals.TestRepo,
  pool: Ecto.Adapters.SQL.Sandbox,
  username: "postgres",
  password: "postgres",
  database: "httpsignals_test"
