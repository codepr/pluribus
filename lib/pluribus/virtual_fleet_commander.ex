defmodule Pluribus.VirtualFleetCommander do
  @moduledoc """
  The application supervisor, responsible for starting all core services and virtual devices
  """

  alias Pluribus.ClusterRegistry
  alias Pluribus.ClusterServiceSupervisor
  alias Pluribus.TelemetryAggregators.ConsoleTelemetryAggregator
  alias Pluribus.VirtualDevice
  alias Pluribus.VirtualDevices.GenericVirtualDevice

  @doc """
  Start a device process in the cluster. The device process will be started in any node of
  the cluster.

  Allowed option entries:

  - `device_id` represents the ID of a virtual device, if not specified a random one will be generated

  ## Examples

      iex> Pluribus.VirtualFleetCommander.start_device(Pluribus.VirtualDevices.GenericVirtualDevice)
      {:ok, <123>}

  """
  @spec start_device(
          state_module :: module(),
          telemetry_aggregator_module :: module(),
          opts :: Keyword.t()
        ) ::
          DynamicSupervisor.on_start_child()
  def start_device(
        state_module,
        telemetry_aggregator_module \\ ConsoleTelemetryAggregator,
        opts \\ []
      ) do
    device_id = Keyword.get(opts, :device_id, generate_device_id())

    Horde.DynamicSupervisor.start_child(
      ClusterServiceSupervisor,
      worker_spec(device_id, state_module, telemetry_aggregator_module, opts)
    )
  end

  @doc """
  Find a device in the cluster by its ID.

  ## Examples

      iex> Pluribus.VirtualFleetCommander.lookup_device(:a_device_id)
      {:ok, <123>}

  """
  @spec lookup_device(device_id :: String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup_device(device_id) do
    case Horde.Registry.lookup(ClusterRegistry, device_id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Start a fleet of devices in the cluster. There is no guarantee that all the devices will
  live in the same node.

  Takes a list of `map()` containing the spec for each virtual device in the fleet.
  Allowed spec entries:

  - `device_id` represents the ID of a virtual device, if not specified a random one will be generated
  - `state_module` the logic of the `VirtualDevice` which defines how its internal state behaves.
    If not specified, a `GenericVirtualDevice` will be set.
  - `aggregator_module` the logic for publishing telemetries produced by the virtual
    device, may be any I/O, e.g writing to a DB, to a broker etc.
    By default if not specified uses the `ConsoleTelemetryAggregator`.

  ### Examples

      iex> Pluribus.VirtualFleetCommander.start_fleet([
            %{
                device_id: "fleet_1_1",
                state_module: GenericVirtualDevice,
                telemetry_aggregator: ConsoleTelemetryAggregator
            },
            %{state_module: GenericVirtualDevice},
            %{}
          ])
  """
  @spec start_fleet(device_spec :: [map()]) :: [DynamicSupervisor.on_start_child()]
  def start_fleet(devices_spec) do
    Enum.map(devices_spec, fn device_spec ->
      device_id = Map.get(device_spec, :device_id, generate_device_id())
      state_module = Map.get(device_spec, :state_module, GenericVirtualDevice)

      telemetry_aggregator_module =
        Map.get(
          device_spec,
          :telemetry_aggregator,
          ConsoleTelemetryAggregator
        )

      opts = Map.get(device_spec, :opts, [])

      Horde.DynamicSupervisor.start_child(
        ClusterServiceSupervisor,
        worker_spec(device_id, state_module, telemetry_aggregator_module, opts)
      )
    end)
  end

  @doc """
  Retrieves the number of virtual devices deployed.

  Returns a map containing count values for the supervisor (same as `DynamicSupervisor.count_children`).
  The map contains the following keys:

    - `:specs` the number of children processes
    - `:active` the count of all actively running child processes managed by this supervisor
    - `:supervisors` the count of all supervisors whether or not the child process is still alive
    - `:workers` the count of all workers, whether or not the child process is still alive

  ## Examples
      iex> Pluribus.VirtualFleetCommander.fleet_count()
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
  def fleet_count, do: Horde.DynamicSupervisor.count_children(Pluribus.ClusterServiceSupervisor)

  @doc """
  Retrieves the telemetry payloads from deployed virtual devices, selected by their ID.

  ## Examples
      iex> Pluribus.VirtualFleetCommander.get_telemetry("device_id")
      %{count: 2, topic: :a_topic}
  """
  @spec get_telemetry(device_id :: String.t()) :: term()
  def get_telemetry(device_id) do
    with {:ok, pid} <- lookup_device(device_id) do
      GenServer.call(pid, :get_telemetry)
    end
  end

  @doc """
  Send a command to a deployed virtual device in the cluster, identified by its ID.
  Command can be anything that is supported by the virtual device implementation.

  ## Example
      iex> Pluribus.VirtualFleetCommander.send_command("device_id", :get_telemetry)
      %{count: 2, topic: :a_topic}
  """
  @spec send_command(device_id :: String.t(), command :: term()) :: term()
  def send_command(device_id, command) do
    with {:ok, pid} <- lookup_device(device_id) do
      GenServer.call(pid, {:command, command})
    end
  end

  defp worker_spec(device_id, state_module, telemetry_aggregator, opts) do
    vd_opts =
      [
        device_id: device_id,
        device_state_module: state_module,
        telemetry_aggregator_module: telemetry_aggregator,
        name: via_tuple(device_id)
      ] ++ opts

    %{
      id: {VirtualDevice, device_id},
      start: {VirtualDevice, :start_link, [vd_opts]},
      type: :worker,
      restart: :transient
    }
  end

  defp via_tuple(device_id) do
    {:via, Horde.Registry, {ClusterRegistry, device_id}}
  end

  defp generate_device_id do
    "#{:erlang.phash2(node())}-#{System.system_time(:microsecond)}-#{:erlang.unique_integer([:positive])}"
  end
end
