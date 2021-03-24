defmodule Behavex.SelectorOperationTest do
  use Behavex.OperationCase, async: true

  alias Behavex.{HighPriorityOperation, LowPriorityOperation}
  alias Behavex.Operations.Selector

  test "failing a high priority test allows low priority to run" do
    HighPriorityOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:prepare, fn 1 -> {:ok, 1} end)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)
    |> expect(:teardown, fn state, :invalid, :failure, env -> {:ok, state, env} end)

    LowPriorityOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:prepare, fn 1 -> {:ok, 1} end)
    |> expect(:on_tick, fn state, env -> {:ok, :success, state, env} end)
    |> expect(:teardown, fn state, :invalid, :success, env -> {:ok, state, env} end)

    {:ok, selector} =
      Selector.create("selector", [], [
        {"first", HighPriorityOperation},
        {"second", LowPriorityOperation}
      ])

    assert_ticks(selector, [:success])
  end

  test "high priority task can preempt a running low priority task" do
    HighPriorityOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:prepare, fn 1 -> {:ok, 1} end)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)
    |> expect(:teardown, fn state, :invalid, :failure, env -> {:ok, state, env} end)
    |> expect(:prepare, fn 1 -> {:ok, 1} end)
    |> expect(:on_tick, fn state, env -> {:ok, :success, state, env} end)
    |> expect(:teardown, fn state, :invalid, :success, env -> {:ok, state, env} end)

    LowPriorityOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:prepare, fn 1 -> {:ok, 1} end)
    |> expect(:on_tick, fn state, env -> {:ok, :running, state, env} end)
    |> expect(:teardown, fn state, :running, :invalid, env -> {:ok, state, env} end)

    {:ok, selector} =
      Selector.create("selector", [], [
        {"first", HighPriorityOperation},
        {"second", LowPriorityOperation}
      ])

    assert_ticks(selector, [:running, :success])
  end
end
