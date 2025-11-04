defmodule Pluribus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @default_discovery_strategy Cluster.Strategy.Epmd
  @default_topology [:"pluribus@n1.dev", :"pluribus@n2.dev", :"pluribus@n3.dev"]

  @cluster_topology Application.compile_env(:pluribus, [:cluster, :topology], @default_topology)
  @cluster_discovery_strategy Application.compile_env(
                                :pluribus,
                                [:cluster, :discovery_strategy],
                                @default_discovery_strategy
                              )

  @impl true
  def start(_type, _args) do
    children = base_children() ++ cluster_children()

    opts = [strategy: :one_for_one, name: Pluribus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp base_children do
    [
      {Horde.Registry, name: Pluribus.ClusterRegistry, keys: :unique, members: :auto},
      {Horde.DynamicSupervisor,
       name: Pluribus.ClusterServiceSupervisor, strategy: :one_for_one, members: :auto}
    ]
  end

  defp cluster_children do
    if cluster_enabled?() do
      [{Cluster.Supervisor, [topologies(), [name: Pluribus.ClusterSupervisor]]}]
    else
      []
    end
  end

  defp topologies do
    [
      pluribus_virtual_fleet: [
        strategy: @cluster_discovery_strategy,
        config: [hosts: @cluster_topology]
      ]
    ]
  end

  defp cluster_enabled? do
    not Enum.empty?(@cluster_topology) and @cluster_topology != nil
  end
end
