import Config

config :logger, :console,
  format: "($metadata) [$level] $message\n",
  metadata: [:file, :line]
