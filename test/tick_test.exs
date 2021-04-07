defmodule Behavex.SimpleTickTest do
  use ExUnit.Case

  alias Behavex.{EvenOperation, Operation, StaticOperation, Tickable, Tree}

  test "creating and ticking node works" do
    {:ok, pid} = Tree.start_link(StaticOperation.node_spec([:running]))
    assert {:ok, :running} = Tickable.tick(pid)
  end

  test "ticking and resetting node works" do
    {:ok, pid} = Tree.start_link(StaticOperation.node_spec([:running]))
    assert {:ok, :running} = Tickable.tick(pid)
    assert :ok = Tickable.reset(pid)
    assert {:ok, :invalid} = Operation.get_status(pid)
  end

  test "nodes can access tree-local store" do
    {:ok, pid} = Tree.start_link(EvenOperation.node_spec())
    assert {:ok, :failure} = Tickable.tick(pid)
    assert {:ok, :success} = Tickable.tick(pid)
  end
end
