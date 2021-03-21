defmodule Behavex.BlackboardTest do
  use ExUnit.Case, async: true

  alias Behavex.Blackboard

  setup do
    Blackboard.reset()
  end

  test "registering new namespace works" do
    assert :ok = Blackboard.register_namespace("store")
  end

  test "registering existing namespace fails" do
    assert :ok = Blackboard.register_namespace("store")
    assert {:error, :already_registered} = Blackboard.register_namespace("store")
  end

  test "resetting blackboard works" do
    assert :ok = Blackboard.register_namespace("store")
    assert :ok = Blackboard.reset()
    assert :ok = Blackboard.register_namespace("store")
  end

  test "writing to blackboard works" do
    assert :ok = Blackboard.register_namespace("store")
    assert :ok = Blackboard.put("store.inventory", 100)
    assert 100 = Blackboard.get("store.inventory")
  end

  test "deleting from blackboard works" do
    assert :ok = Blackboard.register_namespace("store")
    assert :ok = Blackboard.put("store.inventory", 100)
    assert 100 = Blackboard.get("store.inventory")
    assert :ok = Blackboard.del("store.inventory")
    refute Blackboard.get("store.inventory")
  end

  test "reading non-existent key returns nil" do
    assert :ok = Blackboard.register_namespace("store")
    refute Blackboard.get("store.inventory")
  end
end
