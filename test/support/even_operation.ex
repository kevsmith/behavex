defmodule Behavex.EvenOperation do
  use Behavex.Operation, mode: :operation

  alias Behavex.Store

  defstruct [:tree_id]

  @impl true
  def on_init(tree_id, _children_, _args) do
    {:ok, %__MODULE__{tree_id: tree_id}}
  end

  @impl true
  def on_reset(:invalid, state) do
    Store.put(state.tree_id, __MODULE__, 1)
    {:ok, state}
  end

  def on_reset(_, state), do: {:ok, state}

  @impl true
  def on_tick(state) do
    {:ok, v} = Store.incr(state.tree_id, __MODULE__)

    case rem(v, 2) do
      0 ->
        {:ok, :success, state}

      _ ->
        {:ok, :failure, state}
    end
  end
end
