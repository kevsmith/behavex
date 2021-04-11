defmodule Behavex.ConfigurableOperation do
  use Behavex.Operation

  alias Behavex.Store

  defstruct current: [], used: [], tree_id: nil

  def on_init(tree_id, _children, [current]) do
    {:ok, %__MODULE__{tree_id: tree_id, current: current}}
  end

  def on_reset(status, state) do
    if status == :running do
      Store.incr(state.tree_id, :resets)
    end

    {:ok, %{state | current: Enum.reverse(state.used) ++ state.current, used: []}}
  end

  def on_tick(%__MODULE__{current: []} = state) do
    [result | current] = Enum.reverse(state.used)
    {:ok, result, %{state | current: current, used: [result]}}
  end

  def on_tick(%__MODULE__{current: [result | current], used: used} = state) do
    {:ok, result, %{state | current: current, used: [result | used]}}
  end
end
