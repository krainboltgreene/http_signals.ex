defmodule HTTPSignals.OutboundRecorder do
  @moduledoc false
  require Logger

  def attach(request, service_name)
      when is_struct(request, Req.Request) and is_binary(service_name) do
    request
    |> Req.Request.put_private(:outbound_service, service_name)
    |> insert_request_step_before(
      :encode_body,
      {:create_http_signal, &create_http_signal/1}
    )
    |> insert_request_step_before(
      :compress_body,
      {:update_http_signal_request_body, &update_http_signal_request_body/1}
    )
    |> insert_response_step_after(
      :decompress_body,
      {:update_http_signal_response, &update_http_signal_response/1}
    )
    |> insert_response_step_after(
      :decode_body,
      {:update_http_signal_response_with_data, &update_http_signal_response_with_data/1}
    )
  end

  defp create_http_signal(request) do
    service_name = Req.Request.get_private(request, :outbound_service)

    try do
      supress_logging(fn ->
        HTTPSignals.create_http_signal(%{
          context_id: Ecto.UUID.generate(),
          service: service_name,
          source: :us,
          stacktrace: HTTPSignals.current_stacktrace(),
          request: %{
            method: request.method,
            scheme: request.url.scheme,
            host: request.url.host,
            port: request.url.port,
            path: request.url.path,
            query: query(request.url.query),
            headers: request.headers,
            data: data(request)
          }
        })
      end)
    rescue
      exception ->
        {:error, exception}
    end
    |> case do
      {:ok, record} ->
        Req.Request.put_private(request, :http_signal_id, record.id)

      {:error, changeset_or_exception} ->
        alert(changeset_or_exception, "Failed to create outbound http request")

        request
        |> Req.Request.put_private(:http_signal_id, nil)
        |> Req.Request.put_private(:http_signal_changeset, changeset_or_exception)
    end
  end

  defp data(request) do
    request.options[:form] || request.options[:form_multipart] || request.options[:json] ||
      request.body
  end

  defp query(nil), do: %{}
  defp query(query), do: URI.decode_query(query)

  defp update_http_signal_request_body(request) do
    http_signal_id = Req.Request.get_private(request, :http_signal_id)

    if http_signal_id do
      try do
        supress_logging(fn ->
          HTTPSignals.update_http_signal_with_postprocessing(
            HTTPSignals.get_http_signal(http_signal_id),
            body(request.body)
          )
        end)
      rescue
        exception ->
          {:error, exception}
      end
      |> case do
        {:ok, _record} ->
          request

        {:error, changeset_or_exception} ->
          alert(
            changeset_or_exception,
            "Failed to update http signal with processed request"
          )

          request
          |> Req.Request.put_private(:http_signal_request_error, changeset_or_exception)
      end
    else
      request
    end
  end

  defp update_http_signal_response({request, response}) do
    http_signal_id = Req.Request.get_private(request, :http_signal_id)

    http_signal_request_error =
      Req.Request.get_private(request, :http_signal_request_error)

    if http_signal_id do
      response =
        try do
          supress_logging(fn ->
            Core.Support.update_http_signal_with_response(
              Core.Support.get_http_signal(http_signal_id),
              %{
                status: response.status,
                headers: response.headers,
                body: body(response.body),
                sent_at: DateTime.utc_now()
              }
            )
          end)
        rescue
          exception ->
            {:error, exception}
        end
        |> case do
          {:ok, record} ->
            response
            |> Req.Response.put_private(:http_signal_id, record.id)

          {:error, changeset_or_exception} ->
            alert(changeset_or_exception, "Failed to update http signal with response")

            response
            |> Req.Response.put_private(:http_signal_response_error, changeset_or_exception)
            |> Req.Response.put_private(:http_signal_request_error, http_signal_request_error)
            |> Req.Response.put_private(:http_signal_id, http_signal_id)
        end

      {request, response}
    else
      {request,
       response
       |> Req.Response.put_private(:http_signal_request_error, http_signal_request_error)}
    end
  end

  defp update_http_signal_response_with_data({request, response}) do
    http_signal_id = Req.Request.get_private(response, :http_signal_id)

    if http_signal_id do
      response =
        try do
          supress_logging(fn ->
            Core.Support.update_http_signal_with_postprocessing(
              Core.Support.get_http_signal(http_signal_id),
              response.body
            )
          end)
        rescue
          exception ->
            {:error, exception}
        end
        |> case do
          {:ok, _record} ->
            response

          {:error, changeset_or_exception} ->
            alert(
              changeset_or_exception,
              "Failed to update http signal with processed response"
            )

            response
            |> Req.Request.put_private(:http_signal_response_data_error, changeset_or_exception)
        end

      {request, response}
    else
      {request, response}
    end
  end

  defp alert(changeset, message) when is_struct(changeset, Ecto.Changeset) do
    Logger.debug(message)
  end

  defp alert(exception, message) do
    Logger.configure(level: :debug)
    Logger.debug(message)
  end

  defp body(nil), do: nil
  defp body(body), do: IO.iodata_to_binary(body)

  defp supress_logging(function) when is_function(function, 0) do
    if Core.env() == "dev" do
      Logger.configure(level: :error)

      tap(function.(), fn _result ->
        Logger.configure(level: :debug)
      end)
    else
      function.()
    end
  end

  defp insert_request_step_before(%Req.Request{} = request, name, step)
       when is_atom(name) and is_tuple(step) do
    # request steps need two lists, see Request.append_request_step/2!
    %{request_steps: request_steps} = request

    request_steps = insert_step(request_steps, name, step, :before)

    %{request | request_steps: request_steps}
  end

  defp insert_response_step_after(%Req.Request{} = request, name, step)
       when is_atom(name) and is_tuple(step) do
    steps = insert_step(request.response_steps, name, step, :after)

    %{request | response_steps: steps}
  end

  defp insert_response_step_before(%Req.Request{} = request, name, step)
       when is_atom(name) and is_tuple(step) do
    steps = insert_step(request.response_steps, name, step, :before)

    %{request | response_steps: steps}
  end

  defp insert_step(steps, name, step, :before), do: insert_step(steps, name, step, 0)

  defp insert_step(steps, name, step, :after), do: insert_step(steps, name, step, 1)

  defp insert_step(steps, name, step, offset) when is_integer(offset) do
    case Enum.find_index(steps, fn {x, _step} -> x == name end) do
      nil ->
        raise "Unable to find step with name: #{name}"

      index ->
        List.insert_at(steps, index + offset, step)
    end
  end
end
