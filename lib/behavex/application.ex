defmodule Behavex.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Behavex.BlackboardSupervisor,
      {Phoenix.PubSub, name: :blackboard}
    ]

    opts = [strategy: :one_for_one, name: Behavex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
