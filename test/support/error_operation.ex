defmodule Behavex.ErrorOperation do
  use Behavex.Operation

  @impl true
  def init(_), do: {:ok, nil}

  @impl true
  def on_tick(_, _), do: :error

  @impl true
  def on_preempt(_, _), do: :error
end
