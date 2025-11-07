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

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            id: String.t(),
            logic_module: module(),
            aggregator_module: module(),
            device_state: map(),
            schedule_ms: integer(),
            alive?: boolean(),
            stats: stats(),
            opts: Keyword.t()
          }

    @typep stats :: %{
             startup_time: integer(),
             command_count: non_neg_integer(),
             telemetry_count: non_neg_integer(),
             telemetry_volume: non_neg_integer()
           }

    defstruct [
      :id,
      :logic_module,
      :aggregator_module,
      :device_state,
      :schedule_ms,
      :alive?,
      :stats,
      :opts
    ]
  end

  @doc """
  Starts the device process. This is called by the device supervisor.

  The `logic_module` must implement the `Pluribus.VirtualDeviceState` behavior.
  The argument is the tuple: `{device_id, logic_module, opts}`.
  """
  def start_link(opts) do
    device_id = Keyword.fetch!(opts, :device_id)

    logic_module =
      Keyword.get(opts, :logic_module, Pluribus.VirtualDevices.GenericVirtualDevice)

    aggregator_module =
      Keyword.get(
        opts,
        :aggregator_module,
        Pluribus.TelemetryAggregators.ConsoleTelemetryAggregator
      )

    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.start_link(
      __MODULE__,
      {device_id, logic_module, aggregator_module, opts},
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
  Public API to retrieve the current statistic of the virtual device.
  """
  def get_stats(name) do
    GenServer.call(name, :get_stats)
  end

  @doc """
  Public API to execute a command to the inner virtual device state.
  """
  def send_command(name, command) do
    GenServer.call(name, {:command, command})
  end

  # ---- GENSERVER CALLBACKS ----

  @impl true
  def init({device_id, logic_module, aggregator_module, opts}) do
    schedule_ms = Keyword.get(opts, :schedule_ms, @default_schedule_ms)

    state = %State{
      id: device_id,
      logic_module: logic_module,
      aggregator_module: aggregator_module,
      schedule_ms: schedule_ms,
      opts: opts
    }

    {:ok, state, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, state) do
    %{id: device_id, logic_module: logic_module, schedule_ms: schedule_ms, opts: opts} =
      state

    case logic_module.init(device_id, opts) do
      {:ok, logic_state} ->
        stats = %{
          startup_time: System.monotonic_time(:millisecond),
          command_count: 0,
          telemetry_count: 0,
          telemetry_volume: 0
        }

        init_state =
          state
          |> Map.put(:device_state, logic_state)
          |> Map.put(:stats, stats)
          |> Map.put(:alive?, true)

        Logger.info("Device #{device_id} starting up: #{Atom.to_string(logic_module)}.init/2")

        Process.send_after(self(), :periodic_update, schedule_ms)

        {:noreply, init_state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:periodic_update, %{device_state: device_state, stats: stats} = state) do
    with {:ok, new_device_state} <- state.logic_module.update_state(device_state),
         {:ok, telemetry} <- state.logic_module.report_telemetry(new_device_state),
         :ok <- state.aggregator_module.publish_telemetry(telemetry) do
      Process.send_after(self(), :periodic_update, state.schedule_ms)

      new_stats = %{
        stats
        | telemetry_count: stats.telemetry_count + 1,
          telemetry_volume: stats.telemetry_volume + telemetry_size(telemetry)
      }

      new_state = %{state | device_state: new_device_state, stats: new_stats}
      {:noreply, new_state}
    else
      {:error, reason} ->
        Logger.error("Device #{state.id} update failed: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_telemetry, _from, state) do
    case state.logic_module.report_telemetry(state.device_state) do
      {:ok, telemetry} ->
        {:reply, telemetry, state}

      {:error, reason} ->
        Logger.error("Device #{state.id} get telemetry failed: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, %{stats: stats} = state) do
    {:reply, stats, state}
  end

  @impl true
  def handle_call({:command, command}, from, %{stats: stats} = state) do
    new_stats = %{stats | command_count: stats.command_count + 1}

    case state.logic_module.handle_command(command, state.device_state) do
      {:noreply, new_device_state} ->
        new_state = %{state | device_state: new_device_state, stats: new_stats}
        GenServer.reply(from, :ok)
        {:noreply, new_state}

      {:reply, reply, new_device_state} ->
        new_state = %{state | device_state: new_device_state, stats: new_stats}
        {:reply, reply, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("Device #{state.id} terminating")
    :ok
  end

  defp telemetry_size(telemetry), do: telemetry |> :erlang.term_to_binary() |> :erlang.byte_size()
end
