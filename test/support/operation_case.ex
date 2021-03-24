defmodule Behavex.OperationStatusMismatch do
  defexception [:message]
end

defmodule Behavex.OperationCase do
  alias Behavex.Operation

  defmacro __using__(args) do
    quote do
      use ExUnit.Case, unquote(args)

      import Mox
      import unquote(__MODULE__)
    end
  end

  def ticks(operation, 1) do
    Operation.tick(operation)
  end

  def ticks(operation, n) do
    case Operation.tick(operation) do
      {:ok, _, operation} ->
        ticks(operation, n - 1)

      :error ->
        :error
    end
  end

  def assert_ticks(operation, statuses) do
    Enum.reduce(Enum.with_index(statuses, 1), operation, fn {status, index}, op ->
      case Operation.tick(op) do
        {:ok, ^status, op} ->
          op

        {:ok, other, op} ->
          raise Behavex.OperationStatusMismatch,
            message: """
            Expected {:ok, #{status}, #{inspect(op)}} on iteration ##{index}.
            Have {:ok, #{other}, #{inspect(op)}}
            """
      end
    end)
  end

  defmacro mockfn(mock, name, args, result) do
    quote do
      Mox.expect(unquote(mock), unquote(name), fn unquote(args) -> unquote(result) end)
    end
  end
end
