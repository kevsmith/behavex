defmodule Behavex.Sequence do
  use Behavex.Operation, mode: :composite

  defstruct [:children, :tree_id]

  @halt_statuses [:failure, :running]

  def on_init(tree_id, children, _args) do
    {:ok, %__MODULE__{tree_id: tree_id, children: children}}
  end

  def on_reset(_status, state) do
    case apply_strategy_while(state.children, &reset_child/1) do
      {:ok, _} ->
        {:ok, state}

      :error ->
        :error
    end
  end

  def on_tick(state) do
    case apply_strategy_while(state.children, tick_until(one_of(@halt_statuses))) do
      {:ok, status} ->
        {:ok, status, state}

      :error ->
        :error
    end
  end
end
