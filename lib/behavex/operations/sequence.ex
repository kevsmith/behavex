defmodule Behavex.Operations.Sequence do
  @moduledoc """
  A sequence will progressively tick over each of its children so long as each child returns
  `success`. If any child returns `failure` or `running` the sequence will halt and the parent
  will adopt the result of this child. If it reaches the last child, it returns with that
  result regardless.
  """
  use Behavex.Operation

  @impl true
  def init(_), do: {:ok, nil}

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
        {:ok, :success, state, env}
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

  defp tick_child(child, _index, state, acc) do
    case Behavex.Operation.tick(child) do
      {:ok, status, child} when status in [:failure, :running] ->
        {:halt, {status, state}, [child | acc]}

      {:ok, :success, child} ->
        {:cont, state, [child | acc]}

      :error ->
        {:halt, {:error, state}, [child | acc]}
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
