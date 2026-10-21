defmodule HTTPSignals.HTTPHeadersType do
  @moduledoc false
  use Ecto.Type

  def type, do: :jsonb

  def cast(headers) when is_list(headers) or is_map(headers) do
    {
      :ok,
      Enum.map(headers, fn
        {header, value} -> [header, value]
        [header, value] -> [header, value]
        [header] -> [header, nil]
      end)
    }
  end

  def cast(_), do: :error

  def dump(headers) when is_map(headers) or is_list(headers) do
    {
      :ok,
      Enum.map(headers, fn
        {header, value} -> [header, value]
        [header, value] -> [header, value]
        [header] -> [header, nil]
      end)
    }
  end

  def load(headers) when is_list(headers) or is_map(headers) do
    {:ok,
     Enum.map(headers, fn
       [key, value] -> {key, value}
       {key, value} -> {key, value}
     end)}
  end
end
