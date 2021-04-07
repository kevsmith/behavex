defmodule Behavex.InitArgs do
  defstruct callback: nil, child_specs: [], args: [], tree_id: nil

  @typedoc """
  Structure used to pass initialization arguments to various
  tree node types.

  Internal use only.
  """
  @opaque t :: %__MODULE__{
            tree_id: String.t(),
            callback: module(),
            child_specs: nil | [Behavex.tree_node_spec()],
            args: any()
          }
end
