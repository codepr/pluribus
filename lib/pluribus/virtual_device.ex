defmodule Pluribus.VirtualDevice do
  @moduledoc """
  Defines the runtime for any virtual device in the system.

  This module handles the core scheduling, message passing, and fault tolerance
  using the GenServer behavior. It delegates all device-specific logic (state
  updates, telemetry generation, command handling) to a separate module that
  implements the Pluribus.VirtualDeviceState behavior.
  """

  require Logger
  use GenServer

  @default_schedule_ms Application.compile_env(:pluribus, :default_schedule_ms, 5_000)

  @doc """
  Starts the device process. This is called by the device supervisor.

  The `logic_module` must implement the `Pluribus.VirtualDeviceState` behavior.
  The argument is the tuple: `{device_id, logic_module, opts}`.
  """
  def start_link(opts) do
    device_id = Keyword.fetch!(opts, :device_id)

    device_state_module =
      Keyword.get(opts, :device_state_module, Pluribus.VirtualDevices.GenericVirtualDevice)

    telemetry_aggregator_module =
      Keyword.get(
        opts,
        :telemetry_aggregator_module,
        Pluribus.TelemetryAggregators.ConsoleTelemetryAggregator
      )

    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.start_link(
      __MODULE__,
      {device_id, device_state_module, telemetry_aggregator_module, opts},
      name: name
    )
  end

  @doc """
    Public API to get the latest public state (telemetry) from a device.
  """
  def get_telemetry(name) do
    GenServer.call(name, :get_telemetry)
  end

  @doc """
  Public API to execute a command to the inner virtual device state.
  """
  def send_command(name, command) do
    GenServer.call(name, {:command, command})
  end

  # ---- GENSERVER CALLBACKS ----

  @impl true
  def init({device_id, device_state_module, telemetry_aggregator_module, opts}) do
    schedule_ms = Keyword.get(opts, :schedule_ms, @default_schedule_ms)

    case device_state_module.init(device_id, opts) do
      {:ok, initial_state} ->
        state = %{
          id: device_id,
          state_module: device_state_module,
          device_state: initial_state,
          telemetry_aggregator: telemetry_aggregator_module,
          schedule_ms: schedule_ms,
          startup_time: System.monotonic_time()
        }

        Logger.info(
          "Device #{device_id} starting up: #{Atom.to_string(device_state_module)}.init/2"
        )

        Process.send_after(self(), :periodic_update, schedule_ms)

        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:periodic_update, state) do
    {:ok, new_device_state} = state.state_module.update_state(state.device_state)

    telemetry = state.state_module.report_telemetry(new_device_state)
    state.telemetry_aggregator.publish_telemetry(telemetry)
    Process.send_after(self(), :periodic_update, state.schedule_ms)
    new_state = %{state | device_state: new_device_state}
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_telemetry, _from, state) do
    telemetry = state.state_module.report_telemetry(state.device_state)
    {:reply, telemetry, state}
  end

  @impl true
  def handle_call({:command, command}, from, state) do
    case state.state_module.handle_command(command, state.device_state) do
      {:noreply, new_device_state} ->
        new_state = %{state | device_state: new_device_state}
        GenServer.reply(from, :ok)
        {:noreply, new_state}

      {:reply, reply, new_device_state} ->
        new_state = %{state | device_state: new_device_state}
        {:reply, reply, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}}
    end
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("Device #{state.id} terminating")
    :ok
  end
end
