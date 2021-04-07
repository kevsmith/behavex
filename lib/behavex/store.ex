defmodule Behavex.Store do
  @moduledoc """
  Shared "blackboard" scoped to a single behaviour tree instance.
  """
  use GenServer

  defstruct [:data]

  def start_link(id),
    do: GenServer.start_link(__MODULE__, [], name: {:via, Registry, {Registry.TreeStore, id}})

  def put(id, key, value), do: call(id, {:put, key, value})

  def get(id, key, default \\ nil), do: call(id, {:get, key, default})

  def incr(id, key), do: call(id, {:incr, key})

  def decr(id, key), do: call(id, {:decr, key})

  def has_key?(id, key), do: call(id, {:has_key?, key})

  def keys(id), do: call(id, :keys)

  @impl true
  def init(_) do
    {:ok, %__MODULE__{data: %{}}}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    {:reply, :ok, %{state | data: Map.put(state.data, key, value)}}
  end

  def handle_call({:get, key, default}, _from, state) do
    {:reply, {:ok, Map.get(state.data, key, default)}, state}
  end

  def handle_call({:incr, key}, _from, state) do
    case atomic_incdec(state.data, key, 1) do
      {nil, _} ->
        {:reply, {:error, :not_a_number}, state}

      {value, data} ->
        {:reply, {:ok, value}, %{state | data: data}}
    end
  end

  def handle_call({:decr, key}, _from, state) do
    case atomic_incdec(state.data, key, -1) do
      {nil, _} ->
        {:reply, {:error, :not_a_number}, state}

      {value, data} ->
        {:reply, {:ok, value}, %{state | data: data}}
    end
  end

  def handle_call({:has_key?, key}, _from, state) do
    {:reply, Map.has_key?(state.data, key), state}
  end

  def handle_call(:keys, _from, state) do
    {:reply, Map.keys(state.data), state}
  end

  @impl true
  def terminate(reason, state) do
    IO.puts("terminating: #{inspect(reason)}")
    {:ok, state}
  end

  defp atomic_incdec(data, key, amt) do
    Map.get_and_update(data, key, fn
      nil -> {0, 1}
      n when is_number(n) -> {n, n + amt}
      v -> {nil, v}
    end)
  end

  defp call(id, message) do
    GenServer.call({:via, Registry, {Registry.TreeStore, id}}, message, :infinity)
  end
end
