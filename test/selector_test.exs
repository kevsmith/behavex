defmodule Behavex.SelectorOperationTest do
  use Behavex.OperationCase, async: true

  alias Behavex.{HighPriorityOperation, MediumPriorityOperation, LowPriorityOperation}
  alias Behavex.Operations.Selector

  test "failing a high priority test allows low priority to run" do
    HighPriorityOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)

    LowPriorityOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:on_tick, fn state, env -> {:ok, :success, state, env} end)

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
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)
    |> expect(:on_tick, fn state, env -> {:ok, :success, state, env} end)

    LowPriorityOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:on_tick, fn state, env -> {:ok, :running, state, env} end)
    |> expect(:on_preempt, fn state, env -> {:ok, state, env} end)

    {:ok, selector} =
      Selector.create("selector", [], [
        {"first", HighPriorityOperation},
        {"second", LowPriorityOperation}
      ])

    assert_ticks(selector, [:running, :success])
  end

  test "previously running task is preempted when higher priority task succeeds" do
    HighPriorityOperation
    |> mockfn(:init, [], {:ok, 1})
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)
    |> expect(:on_tick, fn state, env -> {:ok, :success, state, env} end)

    MediumPriorityOperation
    |> mockfn(:init, [], {:ok, 1})
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)

    LowPriorityOperation
    |> mockfn(:init, [], {:ok, 1})
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:on_tick, fn state, env -> {:ok, :running, state, env} end)
    |> expect(:on_preempt, fn state, env -> {:ok, state, env} end)

    {:ok, selector} =
      Selector.create("selector", [], [
        {"hi", HighPriorityOperation},
        {"mid", MediumPriorityOperation},
        {"lo", LowPriorityOperation}
      ])

    assert_ticks(selector, [:running, :success])
  end

  test "error during preemption aborts operation" do
    HighPriorityOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)
    |> expect(:on_tick, fn state, env -> {:ok, :success, state, env} end)

    LowPriorityOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:on_tick, fn state, env -> {:ok, :running, state, env} end)
    |> expect(:on_preempt, fn _state, _env -> :error end)

    {:ok, selector} =
      Selector.create("selector", [], [
        {"first", HighPriorityOperation},
        {"second", LowPriorityOperation}
      ])

    assert_ticks(selector, [:running, :error])
  end

  test "all failures cause selector to return failure" do
    HighPriorityOperation
    |> mockfn(:init, [], {:ok, 1})
    |> mockfn(:children_allowed?, [_], false)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)

    LowPriorityOperation
    |> mockfn(:init, [], {:ok, 1})
    |> mockfn(:children_allowed?, [_], false)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)

    {:ok, selector} =
      Selector.create("selector", [], [
        {"hi", HighPriorityOperation},
        {"lo", LowPriorityOperation}
      ])

    assert_ticks(selector, [:failure, :failure, :failure])
  end

  test "preemption flows to children" do
    HighPriorityOperation
    |> mockfn(:init, [], {:ok, 1})
    |> mockfn(:children_allowed?, [_], false)
    |> expect(:on_preempt, fn state, env -> {:ok, state, env} end)

    LowPriorityOperation
    |> mockfn(:init, [], {:ok, 1})
    |> mockfn(:children_allowed?, [_], false)
    |> expect(:on_preempt, fn state, env -> {:ok, state, env} end)

    {:ok, selector} =
      Selector.create("selector", [], [
        {"hi", HighPriorityOperation},
        {"lo", LowPriorityOperation}
      ])

    assert {:ok, _selector} = Behavex.Operation.preempt(selector)
  end

  test "tick error aborts operation" do
    HighPriorityOperation
    |> mockfn(:init, [], {:ok, 1})
    |> mockfn(:children_allowed?, [_], false)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)

    LowPriorityOperation
    |> mockfn(:init, [], {:ok, 1})
    |> mockfn(:children_allowed?, [_], false)
    |> expect(:on_tick, fn _state, _env -> :error end)

    {:ok, selector} =
      Selector.create("selector", [], [
        {"hi", HighPriorityOperation},
        {"lo", LowPriorityOperation}
      ])

    assert :error = Behavex.Operation.tick(selector)
  end

  test "preempt error aborts operation" do
    HighPriorityOperation
    |> mockfn(:init, [], {:ok, 1})
    |> mockfn(:children_allowed?, [_], false)
    |> expect(:on_tick, fn state, env -> {:ok, :failure, state, env} end)
    |> expect(:on_preempt, fn _state, _env -> :error end)

    LowPriorityOperation
    |> mockfn(:init, [], {:ok, 1})
    |> mockfn(:children_allowed?, [_], false)
    |> expect(:on_tick, fn state, env -> {:ok, :running, state, env} end)

    {:ok, selector} =
      Selector.create("selector", [], [
        {"hi", HighPriorityOperation},
        {"lo", LowPriorityOperation}
      ])

    assert {:ok, :running, selector} = Behavex.Operation.tick(selector)
    assert :error = Behavex.Operation.preempt(selector)
  end
end
