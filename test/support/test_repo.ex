defmodule HTTPSignals.TestRepo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :http_signals,
    adapter: Ecto.Adapters.Postgres
end
