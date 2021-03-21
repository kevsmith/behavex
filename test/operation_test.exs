defmodule Behavex.OperationTest do
  use ExUnit.Case, async: true

  alias Behavex.Operation
  alias Behavex.MockOperation
  alias Behavex.ErrorOperation

  import Mox

  setup :verify_on_exit!

  test "creating operation w/no args works" do
    MockOperation
    |> expect(:init, fn [] -> {:ok, :blah} end)
    |> expect(:children_allowed?, fn _ -> false end)

    assert {:ok, op} = Operation.create("Mock", MockOperation, [])
    assert "Mock" == Operation.get_name(op)
    assert true == Enum.empty?(Operation.get_children(op))
  end

  test "creating operation w/args works" do
    MockOperation
    |> expect(:init, fn [1, 2, 3] -> {:ok, nil} end)
    |> expect(:children_allowed?, fn _ -> false end)

    assert {:ok, _op} = Operation.create("Mock", MockOperation, [1, 2, 3])
  end

  test "returning error from init aborts operation creation" do
    MockOperation |> expect(:init, fn _ -> :error end)
    assert :error = mock_operation()
  end

  test "prepare/1 is called on first tick" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, nil} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:prepare, fn nil -> {:ok, 1} end)
    |> expect(:on_tick, fn 1, _ -> {:ok, :running, 2} end)

    {:ok, op} = mock_operation()
    {:ok, :running, _} = ticks(op, 1)
  end

  test "returning :error from prepare/1 aborts operation" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:prepare, fn 1 -> :error end)

    {:ok, op} = mock_operation()
    :error = ticks(op, 1)
  end

  test "teardown/1 is called after :success" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, nil} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:prepare, fn nil -> {:ok, 1} end)
    |> expect(:on_tick, fn 1, _ -> {:ok, :success, 2} end)
    |> expect(:teardown, fn 2, :invalid, :success -> {:ok, 3} end)

    {:ok, op} = mock_operation()
    {:ok, :success, _} = ticks(op, 1)
  end

  test "returning :error from teardown/1 aborts operation" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:prepare, fn 1 -> {:ok, 2} end)
    |> expect(:on_tick, fn 2, _ -> {:ok, :success, 3} end)
    |> expect(:teardown, fn 3, :invalid, :success -> :error end)

    {:ok, op} = mock_operation()
    :error = ticks(op, 1)
  end

  test "returning :running from on_tick/2 keeps operation alive" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:prepare, fn 1 -> {:ok, 2} end)
    |> expect(:on_tick, fn 2, _ -> {:ok, :running, 3} end)
    |> expect(:on_tick, fn 3, _ -> {:ok, :running, 4} end)
    |> expect(:on_tick, fn 4, _ -> {:ok, :failure, 5} end)
    |> expect(:teardown, fn 5, :running, :failure -> {:ok, 6} end)

    {:ok, op} = mock_operation()
    {:ok, :failure, op} = ticks(op, 3)
    assert :invalid == Operation.get_status(op)
  end

  test "returning :error from teardown/1 aborts operation after multiple ticks" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:prepare, fn 1 -> {:ok, 2} end)
    |> expect(:on_tick, fn 2, _ -> {:ok, :running, 3} end)
    |> expect(:on_tick, fn 3, _ -> {:ok, :success, 4} end)
    |> expect(:teardown, fn 4, :running, :success -> :error end)

    {:ok, op} = mock_operation()
    :error = ticks(op, 2)
  end

  test "multiple runs follow the correct call sequence" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:prepare, fn 1 -> {:ok, 2} end)
    |> expect(:on_tick, fn 2, _ -> {:ok, :running, 3} end)
    |> expect(:on_tick, fn 3, _ -> {:ok, :failure, 4} end)
    |> expect(:teardown, fn 4, :running, :failure -> {:ok, 5} end)
    |> expect(:prepare, fn 5 -> {:ok, 6} end)
    |> expect(:on_tick, fn 6, _ -> {:ok, :running, 7} end)
    |> expect(:on_tick, fn 7, _ -> {:ok, :success, 8} end)
    |> expect(:teardown, fn 8, :running, :success -> {:ok, 9} end)

    {:ok, op} = mock_operation()
    {:ok, :success, op} = ticks(op, 4)
    assert :invalid == Operation.get_status(op)
  end

  test "adding empty children works" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> true end)
    |> expect(:prepare, fn 1 -> {:ok, 2} end)
    |> expect(:on_tick, fn 2, _ -> {:ok, :running, 3} end)
    |> expect(:on_tick, fn 3, _ -> {:ok, :failure, 4} end)
    |> expect(:teardown, fn 4, :running, :failure -> {:ok, 5} end)

    {:ok, op} = mock_operation()
    {:ok, :failure, op} = ticks(op, 2)
    assert :invalid == Operation.get_status(op)
    assert Enum.empty?(Operation.get_children(op))
  end

  test "module spec children works" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> true end)

    children = [{"1", ErrorOperation}, {"2", ErrorOperation}]
    {:ok, op} = Operation.create("Mock", MockOperation, [], children)
    assert 2 == Enum.count(Operation.get_children(op))
  end

  test "module & args spec children works" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> true end)

    children = [{"1", ErrorOperation, [1]}, {"2", ErrorOperation, [2]}]
    {:ok, op} = Operation.create("Mock", MockOperation, [], children)
    assert 2 == Enum.count(Operation.get_children(op))
  end

  test "children are kept in order given" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> true end)

    children = for x <- 1..5, do: {"#{x}", ErrorOperation}
    {:ok, op} = Operation.create("Mock", MockOperation, [], children)
    children = Operation.get_children(op)
    assert 5 = Enum.count(children)

    Enum.each(0..4, fn p ->
      child = Enum.at(children, p)
      assert "#{p + 1}" == Operation.get_name(child)
    end)
  end

  test "struct specs work" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> true end)

    children =
      for x <- 1..5 do
        {:ok, op} = ErrorOperation.create("#{x}", [x])
        op
      end

    {:ok, op} = Operation.create("Mock", MockOperation, [], children)
    assert 5 == Enum.count(Operation.get_children(op))
  end

  test "mixed specs work" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> true end)

    children = [{"2", ErrorOperation}, {"3", ErrorOperation, []}]
    {:ok, child} = Operation.create("1", ErrorOperation)
    {:ok, op} = Operation.create("Mock", MockOperation, [], [child | children])
    stored_children = Operation.get_children(op)
    assert 3 == Enum.count(stored_children)
    assert ["1", "2", "3"] == Enum.map(stored_children, &Operation.get_name(&1))
  end

  test "preempting operations works" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> true end)
    |> expect(:prepare, fn 1 -> {:ok, 2} end)
    |> expect(:on_tick, fn 2, _ -> {:ok, :running, 3} end)
    |> expect(:teardown, fn 3, :running, :invalid -> {:ok, 4} end)

    {:ok, op} = mock_operation()
    {:ok, :running, op} = ticks(op, 1)
    {:ok, op} = Operation.preempt(op)
    assert :invalid == Operation.get_status(op)
  end

  defp mock_operation(args \\ []) do
    Operation.create("Mock", MockOperation, args)
  end

  defp ticks(operation, 1) do
    Operation.tick(operation)
  end

  defp ticks(operation, n) do
    case Operation.tick(operation) do
      {:ok, _, operation} ->
        ticks(operation, n - 1)

      :error ->
        :error
    end
  end
end
