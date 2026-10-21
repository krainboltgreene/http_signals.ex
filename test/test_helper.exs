Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)

Code.require_file("support/setup_migration.exs", __DIR__)

# Load up the repository, start it, and run migrations
_ = Ecto.Adapters.Postgres.storage_down(HTTPSignals.TestRepo.config())
:ok = Ecto.Adapters.Postgres.storage_up(HTTPSignals.TestRepo.config())

{:ok, pid} = HTTPSignals.TestRepo.start_link()

:ok = Ecto.Migrator.up(HTTPSignals.TestRepo, 0, HTTPSignals.SetupMigration, log: false)

Ecto.Adapters.SQL.Sandbox.mode(HTTPSignals.TestRepo, {:shared, pid})

ExUnit.start()
