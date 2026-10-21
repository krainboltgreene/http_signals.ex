defmodule HTTPSignals do
  @moduledoc """
  Documentation for `HTTPSignals`.
  """

  @doc """
  Hello world.
  """
  def current_stacktrace() do
    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)

    stacktrace
    |> Enum.drop(2)
    |> Exception.format_stacktrace()
  end

  def get_header(headers, header) when is_list(headers) and is_binary(header) do
    headers
    |> Enum.find(fn [key, _value] -> key == header end)
    |> case do
      nil -> nil
      [_key, value] -> value
    end
  end

  def get_http_signal(id) do
    repo().get(__MODULE__.HTTPSignal, id)
  end

  def create_http_signal(attributes) do
    repo().insert(__MODULE__.HTTPSignal.changeset(%__MODULE__.HTTPSignal{}, attributes))
  end

  def update_http_signal_with_postprocessing(%__MODULE__.HTTPSignal{} = http_signal, body) do
    repo().update(
      __MODULE__.HTTPSignal.postprocess_request_changeset(http_signal, %{request: %{body: body}})
    )
  end

  def update_http_signal_with_response(http_signal, response) do
    repo().update(
      __MODULE__.HTTPSignal.with_response_changeset(http_signal, %{
        response: response
      })
    )
  end

  def repo() do
    Application.get_env(:http_signals, :repo) ||
      raise("You need to define a repository for the Ecto schema of an HTTP Signal")
  end

  def debug?() do
    Application.get_env(:http_signals, :debug?, false)
  end
end
