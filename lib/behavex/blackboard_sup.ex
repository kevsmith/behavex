defmodule Behavex.BlackboardSupervisor do
  use Supervisor

  @moduledoc false

  def start_link(args), do: Supervisor.start_link(__MODULE__, args)

  @impl true
  def init(_) do
    tid = :ets.new(:blackboard, [:set, :public, {:read_concurrency, true}])

    Supervisor.init([{Behavex.Blackboard, [tid]}], strategy: :one_for_one)
  end
end
