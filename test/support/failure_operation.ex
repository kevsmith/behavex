defmodule Behavex.FailureOperation do
  use Behavex.Operation

  def init(_), do: {:ok, 1}

  def on_tick(1, env), do: {:ok, :failure, 1, env}
end
