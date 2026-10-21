defmodule HTTPSignals.SetupMigration do
  @moduledoc false
  use Ecto.Migration

  def change do
    create(table(:http_signals, primary_key: [name: :id, type: :binary_id])) do
      add(:service, :text, null: false)
      add(:source, :text, null: false)
      add(:context_id, :binary_id)
      add(:request, :map, null: false)
      add(:response, :map)
      add(:rejection, :map)
      add(:stacktrace, :text)
      timestamps()
    end
  end
end
