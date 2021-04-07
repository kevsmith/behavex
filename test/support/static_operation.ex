defmodule Behavex.StaticOperation do
  use Behavex.Operation, mode: :operation

  def on_init(_tree_id, _children, [state]) do
    {:ok, state}
  end

  def on_reset(_status, state), do: {:ok, state}

  def on_tick(state), do: {:ok, state, state}
end
