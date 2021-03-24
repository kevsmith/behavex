defmodule Behavex.Operations.Selector do
  use Behavex.Operation

  defstruct last_index: -1

  @impl true
  def init(_) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def children_allowed?(%__MODULE__{}), do: true

  @impl true
  def on_tick(%__MODULE__{} = state, env) do
    tick_children(state, env)
  end

  @impl true
  def teardown(%__MODULE__{} = state, _old_status, _new_status, env) do
    {:ok, state, env}
  end

  defp tick_children(%__MODULE__{last_index: index} = state, env) when index == -1 do
    max_index = length(get_children(env)) - 1
    tick_children(state, env, 0, max_index)
  end

  defp tick_children(%__MODULE__{last_index: last_index} = state, env) do
    case tick_child(env, last_index) do
      {:ok, :running, env} ->
        {:ok, :running, %{state | last_index: last_index}, env}

      {:ok, :failure, env} ->
        with {:ok, env} <- preempt_child(env, last_index) do
          tick_children(%{state | last_index: -1}, env)
        end

      {:ok, :success, env} ->
        {:ok, :success, %{state | last_index: -1}, env}
    end

    max_index = length(get_children(env)) - 1
    tick_children(state, env, last_index, max_index)
  end

  defp tick_children(state, env, index, max_index) when index == max_index do
    case tick_child(env, max_index) do
      {:ok, status, env} ->
        {:ok, status, %{state | last_index: -1}, env}

      :error ->
        :error
    end
  end

  defp tick_children(state, env, index, max_index) do
    case tick_child(env, index) do
      {:ok, :running, env} ->
        {:ok, :running, %{state | last_index: index}, env}

      {:ok, :failure, env} ->
        tick_children(state, env, index + 1, max_index)

      {:ok, :success, env} ->
        {:ok, :success, %{state | last_index: -1}, env}

      :error ->
        :error
    end
  end
end
