import Config

if config_env() == :prod do
  # Load cluster configuration from environment variables
  topology =
    System.get_env("CLUSTER_TOPOLOGY", "")
    |> String.split(",")
    |> Enum.map(&String.to_atom/1)
    |> Enum.reject(&(&1 == :""))

  discovery_strategy =
    System.get_env("CLUSTER_DISCOVERY_STRATEGY", "Elixir.Cluster.Strategy.Epmd")
    |> String.to_existing_atom()

  config :pluribus,
    cluster: [
      topology: topology,
      discovery_strategy: discovery_strategy
    ]
end
