# Vendored and adapted from: https://github.com/adam12/ecto_network/blob/master/lib/ecto_network/inet.ex
#
# The MIT License (MIT)
# Copyright (c) 2016 Adam Daniels and contributors

defmodule HTTPSignals.IPType do
  @moduledoc ~S"""
  Support for using Ecto with `:inet` fields.
  """
  use Ecto.Type

  def type(), do: :map

  @doc "Handle embedding format for CIDR records."
  def embed_as(:json), do: :dump

  @doc "Handle equality testing for CIDR records."
  def equal?(left, right), do: left == right

  @doc "Handle casting to Postgrex.INET."
  def cast(address) when is_map(address) do
    {:ok, address}
  end

  def cast(address) when is_tuple(address) do
    cast(%{address: Tuple.to_list(address), netmask: address_netmask(address)})
  end

  def cast(address) when is_binary(address) do
    {address, netmask} =
      case String.split(address, "/") do
        [address] -> {address, nil}
        [address, netmask] -> {address, netmask}
        [address, netmask | _] -> {address, netmask}
      end

    parsed_address =
      address
      |> String.trim()
      |> String.to_charlist()
      |> :inet.parse_strict_address()

    parsed_netmask = cast_netmask(netmask, parsed_address)

    case [parsed_address, parsed_netmask] do
      [_address_result, :error] ->
        :error

      [{:ok, address}, {netmask, ""}] ->
        {:ok, %{address: Tuple.to_list(address), netmask: netmask}}

      _ ->
        :error
    end
  end

  def cast(_), do: :error

  @doc "Load from the native Ecto representation."
  def load(inet) when is_map(inet) do
    address = inet["address"] || inet[:address]
    netmask = inet["netmask"] || inet[:netmask]

    cond do
      address_netmask(address, netmask) -> %{address: address, netmask: netmask}
      address_netmask(address) -> %{address: address, netmask: address_netmask(address)}
    end
    |> then(&{:ok, &1})
  end

  def load(_), do: :error

  @doc "Convert to the native Ecto representation."
  def dump(inet) when is_map(inet) do
    {:ok,
     %{
       address: inet.address,
       network: inet.netmask || address_netmask(inet.address)
     }}
  end

  def dump(_), do: :error

  @doc "Convert from native Ecto representation to a binary."
  def decode(%{address: address, netmask: netmask}) do
    netmask = address_netmask(address, netmask)

    address
    |> :inet.ntoa()
    |> case do
      {:error, _} ->
        :error

      address ->
        address = List.to_string(address)
        if netmask, do: "#{address}/#{netmask}", else: address
    end
  end

  defp address_netmask(address) when tuple_size(address) == 4, do: 32
  defp address_netmask(_address), do: 128

  defp address_netmask(address, netmask) when tuple_size(address) == 4 and netmask == 32, do: nil
  defp address_netmask(address, netmask) when tuple_size(address) == 8 and netmask == 128, do: nil
  defp address_netmask(_address, netmask), do: netmask

  defp cast_netmask(mask, _address) when is_binary(mask) do
    mask
    |> String.trim()
    |> Integer.parse()
  end

  # For addresses without a netmask, use the default (full) mask.
  # Returns same structure as a successful Integer.parse()
  defp cast_netmask(nil, {:ok, address}) do
    {address_netmask(address), ""}
  end

  defp cast_netmask(_mask, _address), do: :error
end
