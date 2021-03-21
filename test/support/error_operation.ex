defmodule Behavex.ErrorOperation do
  use Behavex.Operation

  def init(_), do: {:ok, 1}

  def on_tick(1, _), do: :error
end
