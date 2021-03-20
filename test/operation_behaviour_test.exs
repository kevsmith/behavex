defmodule Behavex.OperationBehaviourTest do
  use ExUnit.Case

  alias Behavex.Operation

  test "simple state tracking works" do
    {:ok, op} = Operation.create("simple", Behavex.SimpleOperation, [2])
    assert "simple" = Operation.name(op)
    assert :invalid = Operation.status(op)
    {:ok, :running, op} = Operation.tick(op)
    {:ok, :running, op} = Operation.tick(op)
    {:ok, :success, _op} = Operation.tick(op)
  end

  test "simple interrupt works" do
    {:ok, op} = Operation.create("simple", Behavex.SimpleOperation, [2])
    assert "simple" = Operation.name(op)
    assert :invalid = Operation.status(op)
    {:ok, :running, op} = Operation.tick(op)
    {:ok, op} = Operation.interrupt(op)
    assert :invalid = Operation.status(op)
    {:ok, :running, op} = Operation.tick(op)
    {:ok, :running, op} = Operation.tick(op)
    {:ok, :success, _op} = Operation.tick(op)
  end

  test "inspecting op returns behaviour name, operation name, status, callback module, and state" do
    {:ok, op} = Operation.create("simple", Behavex.SimpleOperation, [2])

    assert "#Behavex.Operation<name:simple,status:invalid,callback:Behavex.SimpleOperation,state:{0, 2}>" ==
             inspect(op)
  end
end
