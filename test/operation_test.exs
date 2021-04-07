defmodule Behavex.OperationTest do
  use ExUnit.Case, async: false

  alias Behavex.{InitArgs, Operation, Tickable}

  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "error on init aborts startup (no children)" do
    Behavex.MockOperation
    |> expect(:on_init, fn "test-tree", nil, [] -> :error end)

    args = %InitArgs{
      callback: Behavex.MockOperation,
      child_specs: nil,
      tree_id: "test-tree",
      args: []
    }

    assert {:error, :error} = Operation.start_link(args)
  end

  test "error on init aborts startup (with children)" do
    Behavex.MockOperation
    |> expect(:on_init, fn "test-tree", [], [] -> :error end)

    args = %InitArgs{
      callback: Behavex.MockOperation,
      child_specs: [],
      tree_id: "test-tree",
      args: []
    }

    assert {:error, :error} = Operation.start_link(args)
  end

  test "error starting children aborts startup" do
    children = [fn _ -> :error end]

    args = %InitArgs{
      callback: Behavex.MockOperation,
      child_specs: children,
      tree_id: "test-tree",
      args: []
    }

    assert {:error, :error} = Operation.start_link(args)
  end

  test "error during reset aborts operation" do
    Behavex.MockOperation
    |> expect(:on_init, fn _, _, _ -> {:ok, nil} end)
    |> expect(:on_reset, fn _, _ -> :error end)

    args = %InitArgs{
      callback: Behavex.MockOperation,
      child_specs: nil,
      tree_id: "test-tree",
      args: []
    }

    assert {:ok, pid} = Operation.start_link(args)
    assert :error = Tickable.tick(pid)
  end

  test "error during tick aborts operation" do
    Behavex.MockOperation
    |> expect(:on_init, fn _, _, _ -> {:ok, nil} end)
    |> expect(:on_reset, fn _, _ -> {:ok, nil} end)
    |> expect(:on_tick, fn _ -> :error end)

    args = %InitArgs{
      callback: Behavex.MockOperation,
      child_specs: nil,
      tree_id: "test-tree",
      args: []
    }

    assert {:ok, pid} = Operation.start_link(args)
    assert :error = Tickable.tick(pid)
  end

  test "error on reset after successful tick aborts operation" do
    Behavex.MockOperation
    |> expect(:on_init, fn _, _, _ -> {:ok, nil} end)
    |> expect(:on_reset, fn _, _ -> {:ok, nil} end)
    |> expect(:on_tick, fn _ -> {:ok, :success, nil} end)
    |> expect(:on_reset, fn _, _ -> :error end)

    args = %InitArgs{
      callback: Behavex.MockOperation,
      child_specs: nil,
      tree_id: "test-tree",
      args: []
    }

    assert {:ok, pid} = Operation.start_link(args)
    assert {:ok, :success} = Tickable.tick(pid)
    assert :error = Tickable.reset(pid)
  end
end
