defmodule Behavex do
  alias Behavex.Operation

  @type tree_node_state :: Operation.state()
  @type tree_node_children :: [pid()]
  @type status :: :invalid | :success | :running | :failure
  @type tree_id :: String.t()
  @type tree_node_spec :: (tree_id -> {:ok, tree_node_state()} | :error)
  @type tree_node_specs :: [tree_node_spec()]
end
