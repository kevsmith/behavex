defmodule Behavex.Blackboard do
  use GenServer

  defstruct [:tid]

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def register_namespace(ns) when is_binary(ns),
    do: GenServer.call(__MODULE__, {:register_ns, ns})

  def put(key, value) do
    case String.split(key, ".", parts: 2) do
      [_] ->
        {:error, :missing_namespace}

      [ns, key_part] ->
        GenServer.call(__MODULE__, {:put, ns, key_part, key, value})
    end
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def del(key) do
    case String.split(key, ".", parts: 2) do
      [_] ->
        {:error, :missing_namespace}

      [ns, key_part] ->
        GenServer.call(__MODULE__, {:del, ns, key_part, key})
    end
  end

  def reset(), do: GenServer.call(__MODULE__, :reset)

  @impl true
  def init([tid]) do
    # Set up bookkeeping entries
    init_storage(tid)
    {:ok, %__MODULE__{tid: tid}}
  end

  @impl true
  def handle_call({:register_ns, ns}, _from, state) do
    reply =
      if is_registered?(state.tid, ns) do
        {:error, :already_registered}
      else
        register_ns(state.tid, ns)
      end

    {:reply, reply, state}
  end

  def handle_call(:reset, _from, state) do
    init_storage(state.tid)
    {:reply, :ok, state}
  end

  def handle_call({:put, ns, key, full_key, value}, _from, state) do
    reply =
      if is_registered?(state.tid, ns) do
        [{:_ns_members, members}] = :ets.lookup(state.tid, :_ns_members)

        :ets.update_element(
          state.tid,
          :_ns_members,
          {2,
           Map.update!(members, ns, fn keys ->
             if Enum.member?(keys, key) do
               keys
             else
               [key | keys]
             end
           end)}
        )

        :ets.insert(state.tid, {full_key, value})
        :ok
      else
        {:error, :not_registered}
      end

    {:reply, reply, state}
  end

  def handle_call({:get, key}, _from, state) do
    reply =
      case :ets.lookup(state.tid, key) do
        [] ->
          nil

        [{^key, value}] ->
          value
      end

    {:reply, reply, state}
  end

  def handle_call({:del, ns, key, full_key}, _from, state) do
    reply =
      if is_registered?(state.tid, ns) do
        [{:_ns_members, members}] = :ets.lookup(state.tid, :_ns_members)
        ns_members = Map.fetch!(members, ns) |> Enum.filter(&(&1 != key))
        members = Map.put(members, ns, ns_members)
        :ets.update_element(state.tid, :_ns_members, {2, members})
        :ets.delete(state.tid, full_key)
        :ok
      else
        {:error, :not_registered}
      end

    {:reply, reply, state}
  end

  defp init_storage(tid) do
    :ets.delete_all_objects(tid)
    :ets.insert_new(tid, [{:_ns, []}, {:_ns_members, %{}}])
  end

  defp is_registered?(tid, ns) do
    [{_, namespaces}] = :ets.lookup(tid, :_ns)
    Enum.member?(namespaces, ns)
  end

  defp register_ns(tid, ns) do
    [{_, namespaces}] = :ets.lookup(tid, :_ns)
    :ets.update_element(tid, :_ns, {2, [ns | namespaces]})
    [{:_ns_members, members}] = :ets.lookup(tid, :_ns_members)
    :ets.update_element(tid, :_ns_members, {2, Map.put(members, ns, [])})
    :ok
  end
end
