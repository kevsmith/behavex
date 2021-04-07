defmodule Behavex.Tree do
  use GenServer

  alias Behavex.{Operation, Store, Tickable}

  defstruct root: nil, tree_id: nil

  def start_link(root) do
    tree_id = UUID.uuid4()
    GenServer.start_link(__MODULE__, [tree_id, root])
  end

  def get_tree_id(pid) do
    GenServer.call(pid, :get_tree_id, :infinity)
  end

  @doc false
  @impl true
  def init([tree_id, root]) do
    {:ok, _store_pid} = Store.start_link(tree_id)

    case root.(tree_id) do
      {:ok, root_pid} ->
        {:ok, %__MODULE__{root: root_pid, tree_id: tree_id}}

      error ->
        error
    end
  end

  @doc false
  @impl true
  def handle_call(:tick, _from, state) do
    {:reply, Tickable.tick(state.root), state}
  end

  def handle_call(:reset, _from, state) do
    {:reply, Tickable.reset(state.root), state}
  end

  def handle_call(:get_status, _from, state) do
    {:reply, Operation.get_status(state.root), state}
  end

  def handle_call(:get_tree_id, _from, state) do
    {:reply, {:ok, state.tree_id}, state}
  end
end
