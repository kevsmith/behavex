defmodule Behavex.CompositeHelpers do
  @moduledoc """
  Reusable helper functions to simplify creating new
  composite behavior tree node types.
  """

  @type tick_strategy ::
          (pid() -> :cont | {:halt, Behavex.status()} | :error)

  alias Behavex.{Operation, Tickable}

  @spec apply_strategy_while(
          children :: Behavex.tree_node_children(),
          strategy :: tick_strategy()
        ) ::
          {:ok, Behavex.status()} | :error
  def apply_strategy_while(children, strategy, opts \\ []) do
    return_child = Keyword.get(opts, :return_child, false)

    case Enum.reduce_while(children, nil, make_executor(strategy, return_child)) do
      :error ->
        :error

      result ->
        {:ok, result}
    end
  end

  def one_of(statuses) do
    &Enum.member?(statuses, &1)
  end

  def tick_until(predicate) do
    fn child ->
      case Tickable.tick(child) do
        {:ok, status} ->
          if predicate.(status) do
            {:halt, status}
          else
            :cont
          end
      end
    end
  end

  def reset_child(child) do
    case Tickable.reset(child) do
      :ok ->
        {:cont, :ok}

      :error ->
        {:halt, :error}
    end
  end

  defp make_executor(strategy, false) do
    fn child, _status ->
      case strategy.(child) do
        {:halt, status} ->
          {:halt, status}

        {:cont, status} ->
          {:cont, status}

        :cont ->
          {:ok, status} = Operation.get_status(child)
          {:cont, status}

        :error ->
          {:halt, :error}
      end
    end
  end

  defp make_executor(strategy, true) do
    fn child, _status ->
      case strategy.(child) do
        {:halt, status} ->
          {:halt, {status, child}}

        {:cont, status} ->
          {:cont, {status, child}}

        :cont ->
          {:ok, status} = Operation.get_status(child)
          {:cont, {status, child}}

        :error ->
          {:halt, :error}
      end
    end
  end
end
