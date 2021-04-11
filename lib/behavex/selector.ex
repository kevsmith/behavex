defmodule Behavex.Selector do
  use Behavex.Operation, mode: :composite

  alias Behavex.Tickable

  defstruct [:children, :last_child, :tree_id]

  @halt_statuses [:success, :running]

  def on_init(tree_id, children, _args) do
    {:ok, %__MODULE__{tree_id: tree_id, children: children, last_child: nil}}
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
    case apply_strategy_while(state.children, tick_until(one_of(@halt_statuses)),
           return_child: true
         ) do
      {:ok, {status, child}} ->
        complete_tick(status, child, state)

      :error ->
        :error
    end
  end

  defp complete_tick(:failure, _child, state), do: {:ok, :failure, state}

  defp complete_tick(:success, _child, %__MODULE__{last_child: nil} = state),
    do: {:ok, :success, state}

  defp complete_tick(:success, child, %__MODULE__{last_child: last_child} = state) do
    if child == last_child do
      {:ok, :success, %{state | last_child: nil}}
    else
      case Tickable.reset(last_child) do
        :ok ->
          {:ok, :success, %{state | last_child: nil}}

        :error ->
          :error
      end
    end
  end

  defp complete_tick(:running, child, %__MODULE__{last_child: nil} = state),
    do: {:ok, :running, %{state | last_child: child}}

  defp complete_tick(:running, child, %__MODULE__{last_child: last_child} = state) do
    if child == last_child do
      {:ok, :running, state}
    else
      case Tickable.reset(last_child) do
        :ok ->
          {:ok, :running, %{state | last_child: child}}

        :error ->
          :error
      end
    end
  end
end
