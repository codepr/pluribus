defmodule Pluribus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      %{
        id: Pluribus.TelemetryAggregator,
        start: {Pluribus.TelemetryAggregator, :start_link, []}
      },
      {Cluster.Supervisor, [topologies(), [name: Pluribus.ClusterSupervisor]]},
      {
        Horde.Registry,
        name: Pluribus.ClusterRegistry, keys: :unique, members: :auto
      },
      {
        Horde.DynamicSupervisor,
        name: Pluribus.ClusterServiceSupervisor, strategy: :one_for_one, members: :auto
      }
    ]

    opts = [strategy: :one_for_one, name: Pluribus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Can also read this from conf files, but to keep it simple just hardcode it for now.
  # It is also possible to use different strategies for autodiscovery.
  # Following strategy works best for docker setup we using for this app.
  defp topologies do
    [
      pluribus_virtual_fleet: [
        strategy: Cluster.Strategy.Epmd,
        config: [
          hosts: [
            :"pluribus@n1.dev",
            :"pluribus@n2.dev",
            :"pluribus@n3.dev"
          ]
        ]
      ]
    ]
  end
end
