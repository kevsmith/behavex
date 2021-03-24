defmodule Behavex.CountingOperation do
  use Behavex.Operation

  def init([max_count]), do: {:ok, {0, max_count}}

  def on_tick({max_count, max_count}, env) do
    {:ok, :success, {0, max_count}, env}
  end

  def on_tick({count, max_count}, env) do
    {:ok, :running, {count + 1, max_count}, env}
  end

  def teardown(state, env) do
    Logger.debug("#{__MODULE__}:#{__ENV__.line} teardown")
    {:ok, state, env}
  end
end
