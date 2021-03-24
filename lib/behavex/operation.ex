defmodule Behavex.Operation do
  require Logger

  defstruct name: nil, children: [], status: nil, cb: nil, cb_state: nil

  @opaque t :: %Behavex.Operation{}
  @type child_spec :: t() | {String.t(), module()} | {String.t(), module(), list(term())}
  @type child_specs :: [] | [child_spec()]
  @type children :: [] | [t()]

  @doc """
  Called when operation instance is created
  """
  @callback init(args :: list()) :: {:ok, term()} | :error

  @doc """
  Called when operation transitions from :invalid to :running
  """
  @callback prepare(state :: term()) :: {:ok, term()} | :error

  @doc """
  Called when one of the following occurs:

  * Operation is pre-empted by higher priority operation
  * Operation has transitioned to :success or :failure
  """
  @callback teardown(
              state :: term(),
              old_status :: Behavex.status(),
              new_status :: Behavex.status(),
              operation_environment :: t()
            ) :: {:ok, term(), t()} | :error

  @doc """
  Called on every tick which represents a meangingful increment
  of time has passed in the simulation/world
  """
  @callback on_tick(state :: term(), operation_environment :: t()) ::
              {:ok, Behavex.status(), term(), t()} | :error

  @doc """
  Called before a child operation is added. Returning false will
  prevent the child from being added.
  """
  @callback children_allowed?(state :: term()) :: boolean()

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__),
        only: [get_name: 1, get_children: 1, tick_child: 2, preempt_child: 2]

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
      def prepare(state), do: {:ok, state}

      @doc false
      @impl true
      def teardown(state, _old_status, _new_status, env), do: {:ok, state, env}

      @doc false
      @impl true
      def children_allowed?(_state), do: false

      defoverridable prepare: 1, teardown: 4, children_allowed?: 1
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
  Returns Operation's children
  """
  @spec get_children(t()) :: children()
  def get_children(%__MODULE__{children: children}), do: children

  if Mix.env() == :test do
    def get_status(%__MODULE__{status: status}), do: status
  end

  @doc """
  Performs a single tick
  """
  @spec tick(t()) :: {:ok, Behavex.status(), t()} | :error
  def tick(%__MODULE__{status: :invalid, cb: cb, cb_state: cb_state} = state) do
    with {:ok, new_cb_state} <- cb.prepare(cb_state) do
      with {:ok, new_status, new_cb_state, %__MODULE__{} = state} <-
             cb.on_tick(new_cb_state, state) do
        if new_status != :running do
          case cb.teardown(new_cb_state, state.status, new_status, state) do
            {:ok, new_cb_state, state} ->
              {:ok, new_status, %{state | status: :invalid, cb_state: new_cb_state}}

            :error ->
              :error
          end
        else
          {:ok, new_status, %{state | status: new_status, cb_state: new_cb_state}}
        end
      end
    end
  end

  def tick(%__MODULE__{cb: cb, cb_state: cb_state} = state) do
    with {:ok, new_status, new_cb_state, %__MODULE__{} = state} <- cb.on_tick(cb_state, state) do
      if new_status != :running do
        case cb.teardown(new_cb_state, state.status, new_status, state) do
          {:ok, new_cb_state, state} ->
            {:ok, new_status, %{state | status: :invalid, cb_state: new_cb_state}}

          :error ->
            :error
        end
      else
        {:ok, new_status, %{state | status: new_status, cb_state: new_cb_state}}
      end
    end
  end

  @doc """
  Performs a single tick on a child

  Returns `:error` if operation has no children or if index is out of bounds
  """
  @spec tick_child(t(), integer()) :: {:ok, Behavex.status(), t()} | :error
  def tick_child(%__MODULE__{children: children} = state, index)
      when index > -1 and index < length(children) do
    {prefix, [target | suffix]} = Enum.split(children, index)

    case tick(target) do
      {:ok, status, target} ->
        {:ok, status, %{state | children: prefix ++ [target] ++ suffix}}

      :error ->
        :error
    end
  end

  def tick_child(%__MODULE__{}, _index), do: :error

  @doc """
  Sends preemption signal to a child

  Returns `:error` if operation has no children or if index is out of bounds
  """
  @spec preempt_child(t(), integer()) :: {:ok, t()} | :error
  def preempt_child(%__MODULE__{children: children} = state, index)
      when index > -1 and index < length(children) do
    {prefix, [target | suffix]} = Enum.split(children, index)

    case preempt(target) do
      {:ok, target} ->
        {:ok, %{state | children: prefix ++ [target] ++ suffix}}

      :error ->
        :error
    end
  end

  def preempt_child(_state, _index), do: :error

  @doc """
  Sends teardown signal to a child

  Returns `:error` if operation has no children or if index is out of bounds
  """
  @spec teardown_child(t(), integer()) :: {:ok, t()} | :error
  def teardown_child(%__MODULE__{children: children} = state, index, old_status, new_status)
      when index > -1 and index < length(children) do
    {prefix, [target | suffix]} = Enum.split(children, index)
    %__MODULE__{cb: cb, cb_state: cb_state} = target

    with {:ok, new_cb_state, new_state} <- cb.teardown(cb_state, old_status, new_status, state) do
      new_target = %{target | cb_state: new_cb_state}
      {:ok, %{new_state | children: prefix ++ [new_target] ++ suffix}}
    end
  end

  def teardown_child(_state, _index), do: :error

  @doc """
  Tells an operation it has been pre-empted by a higher priority operation
  """
  @spec preempt(t()) :: {:ok, t()} | :error
  def preempt(%__MODULE__{cb: cb, cb_state: cb_state, status: :running} = state) do
    with {:ok, new_cb_state, state} <- cb.teardown(cb_state, :running, :invalid, state) do
      {:ok, %{state | cb_state: new_cb_state, status: :invalid}}
    end
  end

  def preempt(state), do: {:ok, state}

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

  defp add_children(state, [{name, callback} | t]) do
    case callback.init([]) do
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

  defimpl Inspect do
    import Inspect.Algebra

    alias Behavex.Operation

    def inspect(%Operation{cb: cb}, opts) do
      concat(["#Behavex.Operation<", to_doc(cb, opts), ">"])
    end
  end
end
