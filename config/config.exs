import Config

config :pluribus,
  default_aggregator: Pluribus.TelemetryAggregators.ConsoleTelemetryAggregator

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:module],
  level: :info
