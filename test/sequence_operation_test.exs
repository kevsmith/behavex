defmodule Behavex.SequenceOperationTest do
  use Behavex.OperationCase, async: true

  alias Behavex.{CountingOperation, FailureOperation}
  alias Behavex.Operations.Sequence

  test "simple sequence works" do
    {:ok, seq} =
      Sequence.create("demo", [], [
        {"first", CountingOperation, [2]},
        {"second", CountingOperation, [0]}
      ])

    assert_ticks(seq, [:running, :running, :success])
  end

  test "last operation becomes the status" do
    {:ok, seq} =
      Sequence.create("demo", [], [
        {"first", CountingOperation, [0]},
        {"second", CountingOperation, [2]}
      ])

    assert_ticks(seq, [:running, :running, :success])
  end

  test "failure becomes the status" do
    {:ok, seq} =
      Sequence.create("demo", [], [
        {"first", CountingOperation, [0]},
        {"second", FailureOperation, []},
        {"second", CountingOperation, [2]}
      ])

    assert_ticks(seq, [:failure, :failure])
  end

  test "failure is returned after running status" do
    {:ok, seq} =
      Sequence.create("demo", [], [
        {"first", CountingOperation, [0]},
        {"second", CountingOperation, [2]},
        {"second", FailureOperation, []}
      ])

    assert_ticks(seq, [:running, :running, :failure])
  end
end
