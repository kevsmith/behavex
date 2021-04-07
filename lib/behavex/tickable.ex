defmodule Behavex.Tickable do
  @moduledoc """
  Provides a common way to tick both operation and composite nodes.
  """

  @doc """
  Ticks a node and blocks until a reply is received
  """
  @spec tick(pid()) :: {:ok, Behavex.status()} | :error
  def tick(pid) do
    GenServer.call(pid, :tick, :infinity)
  end

  @doc """
  Resets any tree node to `:invalid` state
  """
  @spec reset(pid()) :: :ok | :error
  def reset(pid), do: GenServer.call(pid, :reset, :infinity)
end
