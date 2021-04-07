defmodule Behavex.SequenceTest do
  use ExUnit.Case

  alias Behavex.{CountOperation, Sequence, Store, Tickable, Tree}

  test "two node sequence works" do
    tree_spec = Sequence.node_spec([CountOperation.node_spec([2]), CountOperation.node_spec([2])])
    assert {:ok, tree} = Tree.start_link(tree_spec)
    {:ok, tree_id} = Tree.get_tree_id(tree)
    assert {:ok, :success} = Tickable.tick(tree)
    assert {:ok, :success} = Tickable.tick(tree)
    assert {:ok, :failure} = Tickable.tick(tree)
    assert {:ok, 4} == Store.get(tree_id, tree_id, 0)
  end
end
