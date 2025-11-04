import Config

config :pluribus,
  cluster: [
    topology: [:"pluribus@n1.dev", :"pluribus@n2.dev", :"pluribus@n3.dev"],
    discovery_strategy: Cluster.Strategy.Epmd
  ]
