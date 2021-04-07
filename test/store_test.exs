defmodule Behavex.StoreTest do
  use ExUnit.Case

  alias Behavex.Store

  @tree_id "test-tree"

  setup do
    Registry.start_link(keys: :unique, name: Registry.TreeStore)
    {:ok, pid} = Store.start_link(@tree_id)
    {:ok, store: pid}
  end

  test "read/write to store works" do
    assert :ok = Store.put(@tree_id, "a", 1)
    assert {:ok, 1} = Store.get(@tree_id, "a")
  end

  test "read/write to missing store fails" do
    try do
      Store.put("foo", "a", 1)
    catch
      :exit, {reason, _} -> assert :noproc == reason
    end

    try do
      Store.get("foo", "a")
    catch
      :exit, {reason, _} -> assert :noproc == reason
    end
  end

  test "incr and decr work" do
    assert :ok = Store.put(@tree_id, "b", 1)
    assert {:ok, 1} = Store.incr(@tree_id, "b")
    assert {:ok, 2} = Store.decr(@tree_id, "b")
  end

  test "incr and decr are atomic" do
    incr = fn
      0, _ ->
        :ok

      x, loop ->
        Store.incr(@tree_id, "c")
        loop.(x - 1, loop)
    end

    decr = fn
      0, _ ->
        :ok

      x, loop ->
        Store.decr(@tree_id, "c")
        loop.(x - 1, loop)
    end

    Store.put(@tree_id, "c", 1)

    tasks =
      Enum.map(1..10, fn x ->
        payload =
          if rem(x, 2) == 0 do
            incr
          else
            decr
          end

        Task.async(fn -> payload.(5, payload) end)
      end)

    Task.await_many(tasks)
    assert Store.get(@tree_id, "c", 1)
  end

  test "querying for keys works" do
    assert :ok = Store.put(@tree_id, "a", 1)
    assert Store.has_key?(@tree_id, "a")
    refute Store.has_key?(@tree_id, "d")
  end

  test "dumping keys works" do
    data = [a: 1, b: 2, c: 3]
    keys = Keyword.keys(data)
    Enum.each(data, fn {key, value} -> Store.put(@tree_id, key, value) end)
    assert [:a, :b, :c] = Store.keys(@tree_id)
  end
end
