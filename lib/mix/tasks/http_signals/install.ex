defmodule Mix.Tasks.HTTPSignals.Install do
  @moduledoc false
  @shortdoc "generates http signals migration file"

  use Mix.Task

  import Macro, only: [underscore: 1]
  import Mix.Generator

  def run(_args) do
    path = Path.relative_to("priv/repo/migrations", Mix.Project.app_path())
    file = Path.join(path, "#{timestamp()}_#{underscore(CreateHTTPSignals)}.exs")

    create_directory(path)

    create_file(file, """
    defmodule Repo.Migrations.CreateHTTPSignals do
      use Ecto.Migration

      def change do
        create(table(:http_signals, primary_key: [name: :id, type: :binary_id])) do
          add :service, :citext, null: false
          add :source, :citext, null: false
          add :context_id, :uuid
          add :request, :map, null: false
          add :response, :map
          add :rejection, :map
          add :stacktrace, :text
          timestamps()
        end

        create(index(:http_signals, [:service, :source, :context_id]))
        create(index(:http_signals, [:source, :context_id]))
        create(index(:http_signals, [:context_id]))
      end
    end
    """)
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)
end
