# Pluribus

Small library to simplify testing of scalable platforms, e.g. MQTT platforms
for IoT, it allows to define custom behaviors and deploy virtual devices in a
cluster of nodes.

Old buried library I wrote ages ago to test out an IoT infra, resurrected and
re-factored a little.

## Roadmap

Currently very rough and ready stage, next mid / long term improvements:

- Better device lifecycle management (e.g. `on_start`, `on_stop` callbacks etc)
- Fleet scaling
- Load strategies (e.g. wave, random burts, ramp up etc)
- Network issues simulation
- Automated scenarios in a test-like DSL
- Dashboard to observe the fleets, load etc
- Pre-built aggregators (e.g. generic MQTT, HTTP / REST, FIX etc)

## Quickstart

Deploy a device in the cluster. The device process will be started in any node of
the cluster.

Allowed option entries:

- `device_id` represents the ID of a virtual device, if not specified a random one
  will be generated
- `aggregator_module` the logic for publishing telemetries produced by the virtual
  device, may be any I/O, e.g writing to a DB, to a broker etc.
  By default if not specified uses the `ConsoleTelemetryAggregator` or the one
  defined in the config module.

```elixir
iex> Pluribus.deploy_device(Pluribus.VirtualDevices.GenericVirtualDevice)
{:ok, <123>}
```

### Custom aggregator module

The following example shows how to define a MQTT (uses [emqtt](https://github.com/emqx/emqtt))
based custom device and aggregator

```elixir
defmodule MQTTTelemetryAggregator do
  use GenServer
  @behaviour Pluribus.TelemetryAggregator

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  # --- TELEMETRY AGGREGATOR CALLBACKS ---

  @impl true
  def publish_telemetry(telemetry) do
    payload = :erlang.term_to_binary(message)
    GenServer.cast(__MODULE__, {:publish, payload})
  end

  # --- GENSERVER CALLBACKS ---

  @impl true
  def init(args) do
    {:ok, pid} = :emqtt.start_link(args)
    {:ok, %{pid: pid}, {:continue, :start_emqtt}}
  end

  @impl true
  def handle_continue(:start_emqtt, %{pid: pid} = state) do
    {:ok, _} = :emqtt.connect(pid)
    emqtt_opts = Application.get_env(:aggregator_module, :emqtt)
    clientid = emqtt_opts[:clientid]
    report_topic = "reports/\#{clientid}/temperature"
    {:noreply, %{state | report_topic: report_topic}}
  end

  @impl true
  def handle_cast({:publish, payload}, state) do
    %{pid: pid, report_topic: report_topic} = state
    :emqtt.publish(pid, report_topic, payload)
    {:noreply, state}
  end
end
```

### Custom virtual device

Handles some state and updates from subscriptions

```elixir
defmodule MQTTVirtualDevice do
  use GenServer
  @behaviour Pluribus.VirtualDeviceState

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  # --- GENSERVER CALLBACKS ---

  @impl true
  def init(args) do
    {:ok, pid} = :emqtt.start_link(args)
    {:ok, %{pid: pid}, {:continue, :start_emqtt}}
  end

  @impl true
  def handle_continue(:start_emqtt, %{pid: pid} = state) do
    {:ok, _} = :emqtt.connect(pid)
    emqtt_opts = Application.get_env(:virtual_device, :emqtt)
    clientid = emqtt_opts[:clientid]
    metrics_topic = "metrics/\#{clientid}/temperature"
    {:ok, _, _} = :emqtt.subscribe(pid, {"metrics/\#{clientid}/temperature", 1})
    {:noreply, %{state | metrics_topic: metrics_topic}}
  end

  @impl true
  def handle_info({:publish, %{payload: payload}}, state) do
    {:noreply, %{state | metrics: :erlang.binary_to_term(payload)}}
  end

  @impl true
  def handle_call(:get_metrics, _from, %{metrics: metrics} = state) do
    {:reply, metrics, state}
  end

  # --- VIRTUAL DEVICE CALLBACKS ---

  @impl true
  def report_telemetry(state) do
    metrics = get_metrics()
    %{
      device_id: state.id,
      device_type: "MQTT_Sensor",
      timestamp: System.os_time(:millisecond),
      data: metrics
    }
  end

  defp get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end
end
```

### Deploy an MQTT virtual device

```elixir
iex> Pluribus.deploy_device(MQTTVirtualDevice, aggregator_module: MQTTTelemetryAggregator)
{:ok, <123>}
```

### Deploy an MQTT virtual device fleet

```elixir
iex> Pluribus.deploy_fleet([
            %{
                device_id: "fleet_1_1",
                logic_module: MQTTVirtualDevice,
                aggregator_module: MQTTTelemetryAggregator,
                opts: [{:clientid, "fleet_1_1"}]
            },
            %{
                device_id: "fleet_1_2",
                logic_module: MQTTVirtualDevice,
                aggregator_module: MQTTTelemetryAggregator,
                opts: [{:clientid, "fleet_1_2"}]
            },
            %{
                device_id: "fleet_1_3",
                logic_module: MQTTVirtualDevice,
                aggregator_module: MQTTTelemetryAggregator,
                opts: [{:clientid, "fleet_1_3"}]
            },
          ])
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pluribus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pluribus, "~> 0.2.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/pluribus>.
