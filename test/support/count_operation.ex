defmodule Behavex.CountOperation do
  use Behavex.Operation

  alias Behavex.Store

  defstruct start_count: 0, count: 0, tree_id: nil

  def on_init(tree_id, _children, [count]) do
    {:ok, %__MODULE__{tree_id: tree_id, start_count: count, count: count}}
  end

  def on_reset(_status, state) do
    {:ok, %{state | count: state.start_count}}
  end

  def on_tick(%__MODULE__{count: 0} = state) do
    {:ok, :failure, state}
  end

  def on_tick(%__MODULE__{count: count} = state) do
    Store.incr(state.tree_id, state.tree_id)
    {:ok, :success, %{state | count: count - 1}}
  end
end
