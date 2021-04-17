defmodule Behavex.Every do
  use Behavex.Operation, mode: :composite

  alias Behavex.Tickable

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
    Enum.each(state.children, fn child -> spawn(fn -> Tickable.tick(child) end) end)
    {:ok, :success, state}
  end
end
