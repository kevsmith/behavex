defmodule Behavex.Operation do
  require Logger

  defstruct name: nil, children: [], status: nil, cb: nil, cb_state: nil

  @opaque t :: %Behavex.Operation{}
  @type child_fun :: (() -> {:ok, t()} | :error)
  @type child_spec :: t() | child_fun() | {String.t(), module(), list(term())}
  @type child_specs :: [] | [child_spec()]

  @doc """
  Called when operation instance is created
  """
  @callback init(args :: list()) :: {:ok, term()} | :error

  @doc """
  Called on every tick which represents a meangingful increment
  of time has passed in the simulation/world
  """
  @callback on_tick(state :: term(), operation_environment :: t()) ::
              {:ok, Behavex.status(), term(), t()} | :error

  @doc """
  Called when an operation is preempted
  """
  @callback on_preempt(state :: term(), operation_environment :: t()) ::
              {:ok, term(), t()} | :error

  @doc """
  Called before a child operation is added. Returning false will
  prevent the child from being added.
  """
  @callback children_allowed?(state :: term()) :: boolean()

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__),
        only: [
          get_name: 1,
          update_child_states: 3
        ]

      require Logger

      @doc """
      Convenience function for creating new instances
      """
      @spec create(name :: String.t(), args :: list(), specs :: unquote(__MODULE__).child_specs()) ::
              {:ok, unquote(__MODULE__).t()} | :error
      def create(name, args \\ [], specs \\ []) do
        unquote(__MODULE__).create(name, __MODULE__, args, specs)
      end

      # Convenience delegates
      defdelegate equiv?(a, b), to: unquote(__MODULE__)

      @doc false
      @impl true
      def children_allowed?(_state), do: false

      @doc false
      @impl true
      def on_preempt(state, env), do: {:ok, state, env}

      defoverridable children_allowed?: 1, on_preempt: 2
    end
  end

  @doc """
  Create an Operation instance
  """
  @spec create(name :: String.t(), callback :: module(), args :: list(), specs :: child_specs()) ::
          {:ok, t()} | :error
  def create(name, callback_module, args \\ [], specs \\ []) do
    with {:ok, internal_state} <- callback_module.init(args) do
      state = %__MODULE__{
        name: name,
        cb: callback_module,
        cb_state: internal_state,
        status: :invalid
      }

      if callback_module.children_allowed?(internal_state) do
        case specs do
          [] ->
            {:ok, state}

          specs ->
            add_children(state, specs)
        end
      else
        case specs do
          [] ->
            {:ok, state}

          _ ->
            :error
        end
      end
    end
  end

  @doc """
  Returns Operation's name
  """
  @spec get_name(t()) :: String.t()
  def get_name(%__MODULE__{name: name}), do: name

  @doc """
  Uses `Enum.reduce_while/3` to apply a function to all
  child states
  """
  def update_child_states(%__MODULE__{children: children} = state, data, mutator) do
    {new_data, new_children} =
      children
      |> Enum.with_index()
      |> Enum.reduce_while({data, []}, fn {child, index}, {data, acc} ->
        case mutator.(child, index, data, acc) do
          {:cont, data, acc} ->
            {:cont, {data, acc}}

          {:halt, data, acc} ->
            {:halt, {data, acc}}
        end
      end)

    {new_data, finish_update(state, Enum.reverse(new_children))}
  end

  def get_status(%__MODULE__{status: status}), do: status

  if Mix.env() == :test do
    def get_children(%__MODULE__{children: children}), do: children
  end

  @doc """
  Performs a single tick
  """
  @spec tick(t()) :: {:ok, Behavex.status(), t()} | :error
  def tick(%__MODULE__{cb: cb, cb_state: cb_state} = state) do
    with {:ok, new_status, new_cb_state, %__MODULE__{} = state} <- cb.on_tick(cb_state, state) do
      {:ok, new_status, %{state | status: new_status, cb_state: new_cb_state}}
    end
  end

  @doc """
  Tells an operation it has been pre-empted by a higher priority operation
  """
  @spec preempt(t()) :: {:ok, t()} | :error
  def preempt(%__MODULE__{cb: cb, cb_state: cb_state} = state) do
    with {:ok, new_cb_state, new_state} <- cb.on_preempt(cb_state, state) do
      {:ok, %{new_state | cb_state: new_cb_state, status: :invalid}}
    end
  end

  @doc """
  Compares two operations checking for equivalency
  Returns true iff callback module names and operation names match
  """
  @spec equiv?(t(), t()) :: boolean()
  def equiv?(%__MODULE__{cb: cb1, name: name1}, %__MODULE__{cb: cb2, name: name2}) do
    cb1 == cb2 and name1 == name2
  end

  def equiv?(_, _), do: false

  defp add_children(%__MODULE__{children: []} = state, []), do: {:ok, state}

  defp add_children(%__MODULE__{children: children} = state, []) do
    {:ok, %{state | children: Enum.reverse(children)}}
  end

  defp add_children(state, [op_state | t]) when is_struct(op_state) do
    add_children(%{state | children: [op_state | state.children]}, t)
  end

  defp add_children(state, [child_fun | t]) when is_function(child_fun) do
    with {:ok, child} <- child_fun.() do
      add_children(%{state | children: [child | state.children]}, t)
    end
  end

  defp add_children(state, [{name, callback, args} | t]) do
    case callback.init(args) do
      {:ok, internal_state} ->
        child = %__MODULE__{
          name: name,
          cb: callback,
          cb_state: internal_state,
          status: :invalid
        }

        add_children(%{state | children: [child | state.children]}, t)

      :error ->
        :error
    end
  end

  defp finish_update(%__MODULE__{children: children} = state, new_children)
       when length(children) == length(new_children) do
    %{state | children: new_children}
  end

  defp finish_update(%__MODULE__{children: children} = state, new_children) do
    new_names = Enum.map(new_children, &get_name(&1))
    remaining = Enum.filter(children, &(Enum.member?(new_names, get_name(&1)) == false))
    %{state | children: new_children ++ remaining}
  end

  defimpl Inspect do
    import Inspect.Algebra

    alias Behavex.Operation

    def inspect(%Operation{cb: cb, name: name}, opts) do
      concat(["#<", to_doc(cb, opts), ">(name:", to_doc(name, opts), ")"])
    end
  end
end
