defmodule Pluribus.VirtualFleetCommander do
  @moduledoc """
  The application supervisor, responsible for starting all core services and virtual devices
  """

  alias Pluribus.ClusterRegistry
  alias Pluribus.ClusterServiceSupervisor
  alias Pluribus.VirtualDevice

  def start(state_module, opts \\ []) do
    device_id = Keyword.get(opts, :device_id, generate_device_id())

    Horde.DynamicSupervisor.start_child(
      ClusterServiceSupervisor,
      worker_spec(device_id, state_module)
    )
  end

  defp worker_spec(device_id, state_module) do
    %{
      id: {VirtualDevice, device_id},
      start:
        {VirtualDevice, :start_link,
         [
           [
             device_id: device_id,
             device_state_module: state_module,
             name: via_tuple(device_id)
           ]
         ]},
      type: :worker,
      restart: :transient
    }
  end

  defp via_tuple(device_id) do
    {:via, Horde.Registry, {ClusterRegistry, device_id}}
  end

  defp generate_device_id do
    :node_1_id_1_placeholder
  end
end
