defmodule Pluribus.VirtualDevices.GenericVirtualDevice do
  @moduledoc """
  A simple device that continuously increments a counter. Serves as an example for how to define
  other device types.

  Implements the Pluribus.VirtualDeviceState behavior.
  """
  require Logger

  @behaviour Pluribus.VirtualDeviceState

  # The internal state struct for the counter device
  defstruct [:id, :count, :max_count]

  # --- Required Behavior Callbacks ---

  @impl true
  def init(device_id, opts) do
    initial_count = Keyword.get(opts, :initial_count, 0)
    max_count = Keyword.get(opts, :max_count, 100)
    {:ok, %__MODULE__{id: device_id, count: initial_count, max_count: max_count}}
  end

  @impl true
  def update_state(state) do
    new_count = state.count + 1

    new_state =
      if new_count > state.max_count do
        Logger.info("Device #{state.id}: Count reset to 0 (exceeded max).")
        %{state | count: 0}
      else
        %{state | count: new_count}
      end

    {:ok, new_state}
  end

  @impl true
  def report_telemetry(state) do
    {:ok,
     %{
       device_id: state.id,
       device_type: "Counter",
       timestamp: System.os_time(:millisecond),
       data: %{
         current_count: state.count,
         count_limit: state.max_count
       }
     }}
  end

  @impl true
  def handle_command({:set_max, new_max}, state) when is_integer(new_max) and new_max > 0 do
    Logger.info("Device #{state.id}: Command received: Setting max_count to #{new_max}")
    {:reply, {:ok, new_max}, %{state | max_count: new_max}}
  end

  def handle_command({:reset_count}, state) do
    Logger.info("Device #{state.id}: Command received: Resetting count.")
    {:reply, :reset_complete, %{state | count: 0}}
  end

  def handle_command(_command, state) do
    {:reply, {:error, :unknown_command}, state}
  end
end
