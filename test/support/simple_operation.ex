defmodule Behavex.SimpleOperation do
  use Behavex.Operation

  @impl true
  def init([max]) do
    {:ok, {0, max}}
  end

  @impl true
  def update({n, max}) when n < max do
    {:ok, :running, {n + 1, max}}
  end

  def update({max, max}) do
    {:ok, :success, {0, max}}
  end

  @impl true
  def stop({_, max}, :invalid) do
    {:ok, {0, max}}
  end

  def stop({_, max}, :success) do
    {:ok, {0, max}}
  end
end
