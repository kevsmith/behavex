defmodule Behavex.OperationTest do
  use Behavex.OperationCase, async: true

  alias Behavex.Operation
  alias Behavex.MockOperation
  alias Behavex.ErrorOperation

  setup :verify_on_exit!

  test "creating operation w/no args works" do
    MockOperation
    |> mockfn(:init, [], {:ok, :blah})
    |> expect(:children_allowed?, fn _ -> false end)

    assert {:ok, op} = Operation.create("Mock", MockOperation, [])
    assert "Mock" == Operation.get_name(op)
    assert true == Enum.empty?(Operation.get_children(op))
  end

  test "creating operation w/args works" do
    MockOperation
    |> mockfn(:init, [1, 2, 3], {:ok, nil})
    |> mockfn(:children_allowed?, nil, false)

    assert {:ok, _op} = Operation.create("Mock", MockOperation, [1, 2, 3])
  end

  test "returning error from init aborts operation creation" do
    MockOperation |> mockfn(:init, [], :error)
    assert :error = mock_operation()
  end

  test "returning :running from on_tick/2 keeps operation alive" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:on_tick, fn 1, env -> {:ok, :running, 2, env} end)
    |> expect(:on_tick, fn 2, env -> {:ok, :running, 3, env} end)
    |> expect(:on_tick, fn 3, env -> {:ok, :failure, 4, env} end)

    {:ok, op} = mock_operation()
    {:ok, :failure, op} = ticks(op, 3)
    assert :failure == Operation.get_status(op)
  end

  test "multiple runs follow the correct call sequence" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> false end)
    |> expect(:on_tick, fn 1, env -> {:ok, :running, 2, env} end)
    |> expect(:on_tick, fn 2, env -> {:ok, :failure, 3, env} end)
    |> expect(:on_tick, fn 3, env -> {:ok, :running, 4, env} end)
    |> expect(:on_tick, fn 4, env -> {:ok, :success, 5, env} end)

    {:ok, op} = mock_operation()
    {:ok, :success, op} = ticks(op, 4)
    assert :success == Operation.get_status(op)
  end

  test "adding empty children works" do
    MockOperation
    |> expect(:init, fn _ -> {:ok, 1} end)
    |> expect(:children_allowed?, fn _ -> true end)
    |> expect(:on_tick, fn 1, env -> {:ok, :running, 2, env} end)
    |> expect(:on_tick, fn 2, env -> {:ok, :failure, 3, env} end)

    {:ok, op} = mock_operation()
    {:ok, :failure, op} = ticks(op, 2)
    assert :failure == Operation.get_status(op)
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

  test "equivalency checks work as expected" do
    {:ok, op1} = ErrorOperation.create("op1")
    {:ok, op2} = ErrorOperation.create("op2")
    assert ErrorOperation.equiv?(op1, op1)
    assert ErrorOperation.equiv?(op2, op2)
    refute ErrorOperation.equiv?(op1, op2)
  end

  defp mock_operation(args \\ []) do
    Operation.create("Mock", MockOperation, args)
  end
end
