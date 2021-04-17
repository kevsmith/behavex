defmodule Behavex.Every do
  use Behavex.Operation, mode: :composite

  defstruct [:children]

  def on_init(_, children, _) do
    {:ok, %__MODULE__{children: children}}
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
    case apply_strategy_while(state.children, &tick_child/1) do
      {:ok, _} ->
        {:ok, :success, state}

      :error ->
        :error
    end
  end
end
