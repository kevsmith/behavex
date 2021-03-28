defmodule Behavex.SequenceTest do
  use Behavex.OperationCase, async: true

  alias Behavex.Operations.Sequence
  alias Behavex.{CountingOperation, ErrorOperation, FailureOperation}

  test "successful sequence works" do
    {:ok, seq} =
      Sequence.create("sequence", [], [
        {"first", CountingOperation, [0]}
      ])

    assert_ticks(seq, [:success])
  end

  test "sequence reports running until all operations succeed" do
    {:ok, seq} =
      Sequence.create("sequence", [], [
        {"first", CountingOperation, [1]},
        {"second", CountingOperation, [0]}
      ])

    assert_ticks(seq, [:running, :success])
  end

  test "sequence reports running until failure" do
    {:ok, seq} =
      Sequence.create("sequence", [], [
        {"first", CountingOperation, [1]},
        {"failure", FailureOperation, []},
        {"second", CountingOperation, [0]}
      ])

    assert_ticks(seq, [:running, :failure])
  end

  test "preemption restarts sequence" do
    {:ok, seq} =
      Sequence.create("sequence", [], [
        {"first", CountingOperation, [1]},
        {"second", CountingOperation, [0]}
      ])

    assert {:ok, :running, seq} = Behavex.Operation.tick(seq)
    assert {:ok, seq} = Behavex.Operation.preempt(seq)
    assert_ticks(seq, [:running, :success])
  end

  test "error aborts sequence" do
    {:ok, seq} =
      Sequence.create("sequence", [], [
        {"error", ErrorOperation, []}
      ])

    assert :error = Behavex.Operation.tick(seq)
  end

  test "error aborts preemption" do
    {:ok, seq} =
      Sequence.create("sequence", [], [
        {"error", ErrorOperation, []}
      ])

    assert :error = Behavex.Operation.preempt(seq)
  end
end
