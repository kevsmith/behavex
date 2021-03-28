defmodule Behavex.CountingOperation do
  use Behavex.Operation

  defstruct count: 0, max_count: 0

  @impl true
  def init([max_count]), do: {:ok, %__MODULE__{count: max_count, max_count: max_count}}

  @impl true
  def on_tick(%__MODULE__{count: 0} = state, env) do
    {:ok, :success, %{state | count: state.max_count}, env}
  end

  @impl true
  def on_tick(state, env) do
    {:ok, :running, %{state | count: state.count - 1}, env}
  end

  @impl true
  def on_preempt(state, env) do
    {:ok, %{state | count: state.max_count}, env}
  end
end
