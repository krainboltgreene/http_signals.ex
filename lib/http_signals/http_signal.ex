defmodule HTTPSignals.HTTPSignal do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime_usec]
  @foreign_key_type :binary_id
  @schema_prefix "public"
  schema "http_signals" do
    field(:service, :string)
    field(:source, Ecto.Enum, values: [:us, :them])
    field(:context_id, Ecto.UUID)
    field(:stacktrace, :string)

    embeds_one :request, __MODULE__.Request, on_replace: :update do
      field(:method, Ecto.Enum, values: [:get, :head, :put, :post, :delete, :patch])
      field(:scheme, Ecto.Enum, values: [:http, :https])
      field(:host, :string)
      field(:port, :integer)
      field(:path, :string)
      field(:query, :map, default: %{})
      field(:headers, HTTPSignals.HTTPHeadersType, default: [])
      field(:remote_ip, HTTPSignals.IPType)
      field(:body, :string)
      field(:data, HTTPSignals.JSONBType)
      field(:accept, :string)
      field(:content_type, :string)
    end

    embeds_one :response, __MODULE__.Response, on_replace: :update do
      field(:status, :integer)
      field(:headers, HTTPSignals.HTTPHeadersType, default: [])
      field(:body, :string)
      field(:data, HTTPSignals.JSONBType)
      field(:content_type, :string)
      field(:sent_at, :utc_datetime_usec)
    end

    embeds_one :rejection, __MODULE__.Rejection do
      field(:type, :string)
      field(:details, :map)
      field(:errored_at, :utc_datetime_usec)
    end

    timestamps()
  end

  def changeset(record, attributes) do
    record
    |> Ecto.Changeset.cast(attributes, [
      :service,
      :context_id,
      :source,
      :stacktrace
    ])
    |> Ecto.Changeset.cast_embed(:request, with: &request_changeset/2, required: true)
    |> Ecto.Changeset.cast_embed(:response, with: &response_changeset/2)
    |> Ecto.Changeset.cast_embed(:rejection,
      with: fn record, attributes ->
        record
        |> Ecto.Changeset.cast(attributes, [:type, :detail, :errored_at])
        |> Ecto.Changeset.validate_required([:type, :details, :errored_at])
      end
    )
    |> Ecto.Changeset.validate_required([
      :service,
      :context_id,
      :source,
      :stacktrace
    ])
  end

  def with_response_changeset(record, attributes) do
    record
    |> Ecto.Changeset.cast(attributes, [])
    |> Ecto.Changeset.cast_embed(:response, with: &response_changeset/2, required: true)
  end

  def with_rejection_changeset(record, %{__exception__: true} = exception) do
    record
    |> Ecto.Changeset.cast(
      %{
        rejection: %{
          type: Atom.to_string(exception.__struct__),
          details: Map.drop(Map.from_struct(exception), [:__exception__]),
          errored_at: DateTime.utc_now()
        }
      },
      []
    )
    |> Ecto.Changeset.cast_embed(:rejection,
      with: fn record, attributes ->
        record
        |> Ecto.Changeset.cast(attributes, [:type, :details, :errored_at])
        |> Ecto.Changeset.validate_required([:type, :details, :errored_at])
      end
    )
  end

  defp request_changeset(record, attributes) do
    record
    |> Ecto.Changeset.cast(attributes, [
      :method,
      :scheme,
      :host,
      :port,
      :path,
      :query,
      :headers,
      :remote_ip,
      :body,
      :data,
      :accept,
      :content_type
    ])
    |> then(fn changeset ->
      if Ecto.Changeset.get_field(changeset, :host) == nil do
        changeset
        |> Ecto.Changeset.put_change(
          :host,
          changeset
          |> Ecto.Changeset.get_field(:headers)
          |> HTTPSignals.get_header("host")
        )
      else
        changeset
      end
    end)
    |> then(fn changeset ->
      if Ecto.Changeset.get_field(changeset, :path) == nil do
        changeset
        |> Ecto.Changeset.put_change(:path, "/")
      else
        changeset
      end
    end)
    |> Ecto.Changeset.validate_required([
      :method,
      :scheme,
      :host,
      :port,
      :path,
      :query,
      :headers
    ])
  end

  defp response_changeset(record, attributes) do
    record
    |> Ecto.Changeset.cast(attributes, [
      :status,
      :headers,
      :body,
      :data,
      :content_type,
      :sent_at
    ])
    |> Ecto.Changeset.validate_required([
      :status,
      :headers,
      :sent_at
    ])
  end

  def postprocess_request_changeset(record, attributes) do
    record
    |> Ecto.Changeset.cast(attributes, [])
    |> Ecto.Changeset.cast_embed(:request,
      required: true,
      with: fn record, attributes ->
        record
        |> Ecto.Changeset.cast(attributes, [
          :data,
          :body,
          :headers,
          :accept,
          :content_type,
          :remote_ip
        ])
      end
    )
  end

  def postprocess_response_changeset(record, attributes) do
    record
    |> Ecto.Changeset.cast(attributes, [])
    |> Ecto.Changeset.cast_embed(:response,
      with: fn record, attributes ->
        record
        |> Ecto.Changeset.cast(attributes, [:data, :content_type])
      end
    )
  end
end
