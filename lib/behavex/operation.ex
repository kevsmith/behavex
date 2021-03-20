defmodule Behavex.Operation do
  @type init_args :: [] | [any()]
  @type state :: any()

  @callback init(init_args()) :: {:ok, state()} | :error
  @callback pre_run(state()) :: {:ok, state()} | :error
  @callback update(state()) :: {:ok, Behavex.status(), state()} | :error
  @callback stop(state(), Behavex.status()) :: {:ok, state()} | :error

  defmacro __using__(_) do
    quote do
      require Logger

      @behaviour unquote(__MODULE__)

      @impl true
      def pre_run(state), do: {:ok, state}

      @impl true
      def stop(state, _status), do: {:ok, state}

      defoverridable(pre_run: 1, stop: 2)
    end
  end

  defstruct [:name, :status, :callback, :state]

  def create(name, module, args \\ []) do
    case module.init(args) do
      {:ok, state} ->
        {:ok, %__MODULE__{name: name, status: :invalid, callback: module, state: state}}

      :error ->
        :error
    end
  end

  def tick(%__MODULE__{status: :invalid, callback: module, state: mod_state} = s) do
    case module.pre_run(mod_state) do
      {:ok, mod_state} ->
        tick(%{s | status: :running, state: mod_state})

      :error ->
        :error
    end
  end

  def tick(%__MODULE__{status: :running, callback: module, state: mod_state} = s) do
    case module.update(mod_state) do
      {:ok, status, mod_state} when status in [:success, :failure] ->
        case module.stop(mod_state, status) do
          {:ok, mod_state} ->
            {:ok, status, %{s | status: status, state: mod_state}}

          :error ->
            :error
        end

      {:ok, :running, mod_state} ->
        {:ok, :running, %{s | status: :running, state: mod_state}}

      :error ->
        :error
    end
  end

  def tick(%__MODULE__{} = s), do: {:ok, s.status, s}

  def interrupt(%__MODULE__{status: :running, callback: module, state: mod_state} = s) do
    case module.stop(mod_state, :invalid) do
      {:ok, mod_state} ->
        {:ok, %{s | status: :invalid, state: mod_state}}

      :error ->
        :error
    end
  end

  def status(%__MODULE__{status: status}), do: status

  def name(%__MODULE__{name: name}), do: name
end

defimpl Inspect, for: Behavex.Operation do
  import Inspect.Algebra

  alias Behavex.Operation

  def inspect(%Operation{name: name, status: status, callback: module, state: state}, opts) do
    impl_name = "#{module}" |> String.replace_leading("Elixir.", "")

    concat([
      "#Behavex.Operation<name:#{name},status:#{status},callback:#{impl_name},state:",
      to_doc(state, opts),
      ">"
    ])
  end
end
