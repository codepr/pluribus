defmodule Pluribus do
  @moduledoc """
  Documentation for `Pluribus`. Allows for management of virtual devices across the cluster,
  delegates most of the features to the underlying `VirtualFleetCommander` module.
  """

  @doc """
  Deploy a device in the cluster. The device process will be started in any node of
  the cluster.

  Allowed option entries:

  - `device_id` represents the ID of a virtual device, if not specified a random one
                will be generated
  - `aggregator_module` the logic for publishing telemetries produced by the virtual
                        device, may be any I/O, e.g writing to a DB, to a broker etc.
                        By default if not specified uses the `ConsoleTelemetryAggregator`.

  ## Examples

      iex> Pluribus.deploy_device(Pluribus.VirtualDevices.GenericVirtualDevice)
      {:ok, <123>}

  """
  @spec deploy_device(state_module :: module(), opts :: Keyword.t()) ::
          DynamicSupervisor.on_start_child()
  def deploy_device(state_module, opts \\ []) do
    aggregator_module =
      Keyword.get(
        opts,
        :aggregator_module,
        Pluribus.TelemetryAggregators.ConsoleTelemetryAggregator
      )

    Pluribus.VirtualFleetCommander.start_device(state_module, aggregator_module, opts)
  end

  @doc """
  Find a device in the cluster by its ID.

  ## Examples

      iex> Pluribus.lookup_device(:a_device_id)
      {:ok, <123>}

  """
  @spec lookup_device(device_id :: atom() | String.t()) :: {:ok, pid()} | {:error, :not_found}
  defdelegate lookup_device(device_id), to: Pluribus.VirtualFleetCommander

  @doc """
  Deploy a fleet of devices in the cluster. There is no guarantee that all the devices will
  live in the same node.

  Takes a list of `map()` containing the spec for each virtual device in the fleet.
  Allowed spec entries:

  - `device_id` represents the ID of a virtual device, if not specified a random one
                will be generated
  - `state_module` the logic of the `VirtualDevice` which defines how its internal state behaves.
                   If not specified, a `GenericVirtualDevice` will be set.
  - `aggregator_module` the logic for publishing telemetries produced by the virtual
                        device, may be any I/O, e.g writing to a DB, to a broker etc.
                        By default if not specified uses the `ConsoleTelemetryAggregator`.

  ### Examples

      iex> Pluribus.deploy_fleet([
            %{device_id: :fleet_1_1, state_module: GenericVirtualDevice, telemetry_aggregator: ConsoleTelemetryAggregator},
            %{device_id: :fleet_1_2, state_module: GenericVirtualDevice, telemetry_aggregator: ConsoleTelemetryAggregator},
            %{device_id: :fleet_1_3, state_module: GenericVirtualDevice, telemetry_aggregator: ConsoleTelemetryAggregator},
            %{state_module: GenericVirtualDevice}, %{}
          ])
  """
  @spec deploy_fleet(device_spec :: [map()]) :: [DynamicSupervisor.on_start_child()]
  defdelegate deploy_fleet(device_spec), to: Pluribus.VirtualFleetCommander, as: :start_fleet

  defdelegate send_command(device_id, command), to: Pluribus.VirtualFleetCommander

  defdelegate get_telemetry(device_id), to: Pluribus.VirtualFleetCommander

  @doc """
  Retrieves the number of virtual devices deployed.

  Returns a map containing count values for the supervisor (same as `DynamicSupervisor.count_children`).
  The map contains the following keys:

    - `:specs` the number of children processes
    - `:active` the count of all actively running child processes managed by
                this supervisor
    - `:supervisors` the count of all supervisors whether or not the child
                     process is still alive
    - `:workers` the count of all workers, whether or not the child process
                 is still alive

  ## Examples
      iex> Pluribus.fleet_count()
      %{
          specs: 5,
          active: 5,
          supervisors: 1,
          workers: 5
        }
  """
  @spec fleet_count :: %{
          specs: non_neg_integer(),
          active: non_neg_integer(),
          supervisors: non_neg_integer(),
          workers: non_neg_integer()
        }
  defdelegate fleet_count, to: Pluribus.VirtualFleetCommander
end
