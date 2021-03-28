defmodule Behavex.Operations.Selector do
  use Behavex.Operation

  defstruct last_index: -1

  @impl true
  def init(_), do: {:ok, %__MODULE__{}}

  @impl true
  def children_allowed?(_state), do: true

  @impl true
  def on_tick(state, env) do
    case update_child_states(env, state, &tick_child/4) do
      {{:error, _state}, _env} ->
        :error

      {{status, state}, env} ->
        {:ok, status, state, env}

      {state, env} ->
        {:ok, :failure, state, env}
    end
  end

  @impl true
  def on_preempt(state, env) do
    case update_child_states(env, state, &preempt_child/4) do
      {{:error, _state}, _env} ->
        :error

      {state, env} ->
        {:ok, state, env}
    end
  end

  defp tick_child(
         child,
         index,
         {status, new_index, %__MODULE__{last_index: last_index} = state},
         acc
       )
       when index == last_index do
    case Behavex.Operation.preempt(child) do
      {:ok, child} ->
        {:halt, {status, %{state | last_index: new_index}}, [child | acc]}

      :error ->
        {:halt, {:error, state}, acc}
    end
  end

  defp tick_child(child, _index, {status, new_index, state}, acc) do
    {:cont, {status, new_index, state}, [child | acc]}
  end

  defp tick_child(child, index, %__MODULE__{} = state, acc) do
    case Behavex.Operation.tick(child) do
      {:ok, status, child} when status in [:running, :success] ->
        if state.last_index == -1 do
          {:halt, {status, %{state | last_index: index}}, [child | acc]}
        else
          {:cont, {status, index, state}, [child | acc]}
        end

      {:ok, :failure, child} ->
        {:cont, state, [child | acc]}

      :error ->
        {:halt, {:error, state}, acc}
    end
  end

  defp preempt_child(child, _index, state, acc) do
    case Behavex.Operation.preempt(child) do
      {:ok, new_child} ->
        {:cont, state, [new_child | acc]}

      :error ->
        {:halt, {:error, state}, [child | acc]}
    end
  end
end
