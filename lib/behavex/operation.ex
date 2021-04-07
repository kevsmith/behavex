defmodule Behavex.Operation do
  @moduledoc """
  Single behavior tree node. Provides execution callbacks only.
  """

  @typedoc """
  Type of behavior tree node
  """
  @type node_type :: :operation | :composite

  @callback on_init(String.t(), Behavex.tree_node_children(), any()) ::
              {:ok, any()} | :error
  @callback on_tick(any()) :: {:ok, Behavex.status(), any()} | :error
  @callback on_reset(Behavex.status(), any()) :: {:ok, any()} | :error
  @callback node_type() :: node_type()

  defstruct cb: nil, cb_state: nil, status: :invalid

  @typedoc """
  Runtime state information
  """
  @opaque state :: %__MODULE__{
            cb: atom(),
            cb_state: any(),
            status: Behavex.status()
          }

  use GenServer

  alias Behavex.InitArgs

  @doc """
  Starts an `Behavex.Operation`-based node and links its process to the caller.

  Do not call this function directly. Using `Behavex.Operation` will insert
  the correct functions into the using module.
  """
  def start_link(%InitArgs{} = args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Gets the node's current status without executing a tick.
  """
  @spec get_status(pid()) :: {:ok, Behavex.status()} | :error
  def get_status(pid) do
    GenServer.call(pid, :get_status, :infinity)
  end

  @doc false
  @impl true
  def init(%InitArgs{callback: callback, args: init_args, tree_id: tree_id, child_specs: nil}) do
    case callback.on_init(tree_id, nil, init_args) do
      {:ok, state} ->
        {:ok, %__MODULE__{cb: callback, cb_state: state, status: :invalid}}

      error ->
        {:stop, error}
    end
  end

  def init(%InitArgs{callback: callback, args: init_args, tree_id: tree_id, child_specs: specs}) do
    case start_children(specs, [], tree_id) do
      {:ok, children} ->
        case callback.on_init(tree_id, children, init_args) do
          {:ok, state} ->
            {:ok, %__MODULE__{cb: callback, cb_state: state, status: :invalid}}

          error ->
            {:stop, error}
        end

      error ->
        {:stop, error}
    end
  end

  @doc false
  @impl true
  def handle_call(:tick, _from, %{cb: cb, cb_state: cb_state, status: status} = state) do
    case maybe_reset(status, cb, cb_state) do
      :error ->
        {:reply, :error, state}

      cb_state ->
        case state.cb.on_tick(cb_state) do
          {:ok, status, new_cb_state} ->
            {:reply, {:ok, status}, %{state | cb_state: new_cb_state, status: status}}

          :error ->
            {:reply, :error, state}
        end
    end
  end

  def handle_call(:reset, _from, %{status: :invalid} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:reset, _from, %{cb: cb, cb_state: cb_state} = state) do
    case cb.on_reset(state.status, cb_state) do
      {:ok, new_cb_state} ->
        {:reply, :ok, %{state | status: :invalid, cb_state: new_cb_state}}

      :error ->
        {:reply, :error, state}
    end
  end

  def handle_call(:get_status, _from, state) do
    {:reply, {:ok, state.status}, state}
  end

  defp maybe_reset(:invalid, cb, cb_state) do
    case cb.on_reset(:invalid, cb_state) do
      {:ok, cb_state} ->
        cb_state

      :error ->
        :error
    end
  end

  defp maybe_reset(_status, _cb, cb_state), do: cb_state

  defp start_children([], acc, _tree_id), do: {:ok, Enum.reverse(acc)}

  defp start_children([spec | t], acc, tree_id) do
    case spec.(tree_id) do
      {:ok, child} ->
        start_children(t, [child | acc], tree_id)

      error ->
        error
    end
  end

  @doc false
  defmacro __using__(opts \\ []) do
    case Keyword.get(opts, :mode, :operation) do
      :operation ->
        quote do
          alias Behavex.InitArgs
          @behaviour unquote(__MODULE__)

          def start_link(tree_id, args) do
            Behavex.Operation.start_link(%InitArgs{
              callback: __MODULE__,
              args: args,
              tree_id: tree_id,
              child_specs: nil
            })
          end

          def node_spec(args \\ []) do
            fn tree_id -> __MODULE__.start_link(tree_id, args) end
          end

          def node_type(), do: :operation
        end

      :composite ->
        quote do
          @behaviour unquote(__MODULE__)

          alias Behavex.InitArgs
          import Behavex.CompositeHelpers

          def start_link(tree_id, child_specs, args) do
            unquote(__MODULE__).start_link(%InitArgs{
              callback: __MODULE__,
              args: args,
              tree_id: tree_id,
              child_specs: child_specs
            })
          end

          def node_spec(child_specs, args \\ []) do
            fn tree_id -> __MODULE__.start_link(tree_id, child_specs, args) end
          end

          def node_type(), do: :composite
        end

      other ->
        raise ArgumentError,
          message: "Unknown mode #{inspect(other)}. Valid modes are :operation and :composite."
    end
  end
end
