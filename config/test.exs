import Config

# Configure your application for test environment
config :pluribus,
  # Use shorter timeouts in tests
  default_schedule_ms: 50,
  # Test-specific configuration
  start_cluster: true,
  # Configure cluster for single-node testing (no clustering in tests)
  cluster: [
    # Use Gossip strategy for local testing, or disable clustering entirely
    topology: [],
    discovery_strategy: []
  ]

# Configure Horde for single-node testing
config :horde,
  # Faster heartbeat for tests
  delta_crdt_options: [sync_interval: 20]

# Disable libcluster for tests (single node testing)
config :libcluster,
  # Don't try to connect to other nodes in tests
  topologies: []

config :logger, level: :warning
config :logger, :console, level: :warning
config :kernel, logger_level: :warning
