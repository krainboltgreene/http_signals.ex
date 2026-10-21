defmodule HTTPSignals.JSONBType do
  @moduledoc false
  use Ecto.Type

  def type, do: :jsonb

  def cast(value) do
    {:ok, value}
  end

  def dump(value) do
    {:ok, value}
  end

  def load(value) do
    {:ok, value}
  end
end
