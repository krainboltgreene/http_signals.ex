defmodule HTTPSignals.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using _opts do
    quote do
      import Ecto
      import Ecto.Query
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(HTTPSignals.TestRepo)
    # on_exit(fn -> Ecto.Adapters.SQL.Sandbox.checkin(HTTPSignals.TestRepo) end)
  end
end
