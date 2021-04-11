defmodule Behavex.SelectorTest do
  use ExUnit.Case

  alias Behavex.{Tree, Tickable, Selector, Store, ConfigurableOperation}

  test "lower priority operation is reset" do
    specs = [
      ConfigurableOperation.node_spec([[:success, :failure]]),
      ConfigurableOperation.node_spec([[:running, :running]])
    ]

    tree_spec = Selector.node_spec(specs)
    assert {:ok, tree} = Tree.start_link(tree_spec)
    {:ok, tree_id} = Tree.get_tree_id(tree)
    assert {:ok, :success} = Tickable.tick(tree)
    assert {:ok, :running} = Tickable.tick(tree)
    assert {:ok, :success} = Tickable.tick(tree)
    assert {:ok, 1} == Store.get(tree_id, :resets, 0)
  end

  test "all failed operations returns :failure" do
    specs = [
      ConfigurableOperation.node_spec([[:failure, :failure, :failure]]),
      ConfigurableOperation.node_spec([[:success, :running, :failure]])
    ]

    tree_spec = Selector.node_spec(specs)
    assert {:ok, tree} = Tree.start_link(tree_spec)
    {:ok, tree_id} = Tree.get_tree_id(tree)
    assert {:ok, :success} = Tickable.tick(tree)
    assert {:ok, :running} = Tickable.tick(tree)
    assert {:ok, :failure} = Tickable.tick(tree)
    assert {:ok, 0} == Store.get(tree_id, :resets, 0)
  end

  test "success or running skips other children" do
    specs = [
      ConfigurableOperation.node_spec([[:success, :running, :success]]),
      ConfigurableOperation.node_spec([[:failure, :failure, :failure]])
    ]

    tree_spec = Selector.node_spec(specs)
    assert {:ok, tree} = Tree.start_link(tree_spec)
    {:ok, tree_id} = Tree.get_tree_id(tree)
    assert {:ok, :success} = Tickable.tick(tree)
    assert {:ok, :running} = Tickable.tick(tree)
    assert {:ok, :success} = Tickable.tick(tree)
    assert {:ok, 0} == Store.get(tree_id, :resets, 0)
  end

  test "higher priority running operation resets lower priority operation" do
    specs = [
      ConfigurableOperation.node_spec([[:failure, :running]]),
      ConfigurableOperation.node_spec([[:running, :failure]])
    ]

    tree_spec = Selector.node_spec(specs)
    assert {:ok, tree} = Tree.start_link(tree_spec)
    {:ok, tree_id} = Tree.get_tree_id(tree)
    assert {:ok, :running} = Tickable.tick(tree)
    assert {:ok, :running} = Tickable.tick(tree)
    assert {:ok, 1} == Store.get(tree_id, :resets, 0)
  end
end
