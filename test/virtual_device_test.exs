defmodule Pluribus.VirtualDeviceTest do
  use ExUnit.Case, async: false

  alias Pluribus.TelemetryAggregators.TestAggregator
  alias Pluribus.VirtualDevice
  alias Pluribus.VirtualDevices.TestDevice

  setup do
    TestAggregator.clear_telemetry()
    :ok
  end

  describe "start_link/1" do
    test "starts a device with minimal options" do
      opts = [
        device_id: "test_device_1",
        device_state_module: TestDevice,
        telemetry_aggregator_module: TestAggregator
      ]

      assert {:ok, pid} = VirtualDevice.start_link(opts)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "starts a device with custom schedule" do
      opts = [
        device_id: "test_device_2",
        device_state_module: TestDevice,
        telemetry_aggregator_module: TestAggregator,
        schedule_ms: 100
      ]

      assert {:ok, pid} = VirtualDevice.start_link(opts)

      # Wait for a few updates
      Process.sleep(350)

      # Should have received at least 2-3 telemetry updates
      telemetry = TestAggregator.get_telemetry()
      assert length(telemetry) >= 2

      GenServer.stop(pid)
    end

    test "requires device_id option" do
      opts = [
        device_state_module: TestDevice,
        telemetry_aggregator_module: TestAggregator
      ]

      assert_raise KeyError, fn ->
        VirtualDevice.start_link(opts)
      end
    end
  end

  describe "get_telemetry/1" do
    test "returns current device telemetry" do
      opts = [
        device_id: "test_device_3",
        device_state_module: TestDevice,
        telemetry_aggregator_module: TestAggregator,
        name: :test_device_3
      ]

      {:ok, _pid} = VirtualDevice.start_link(opts)

      telemetry = VirtualDevice.get_telemetry(:test_device_3)

      assert telemetry.device_id == "test_device_3"
      assert is_integer(telemetry.counter)
      assert is_integer(telemetry.timestamp)

      GenServer.stop(:test_device_3)
    end
  end

  describe "send_command/2" do
    setup do
      opts = [
        device_id: "test_device_4",
        device_state_module: TestDevice,
        telemetry_aggregator_module: TestAggregator,
        name: :test_device_4
      ]

      {:ok, pid} = VirtualDevice.start_link(opts)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid)
      end)

      {:ok, pid: pid}
    end

    test "handles command that returns reply" do
      assert {:ok, value} = VirtualDevice.send_command(:test_device_4, {:increment, 5})
      assert is_integer(value)
    end

    test "handles command that returns noreply" do
      assert :ok = VirtualDevice.send_command(:test_device_4, :reset)

      telemetry = VirtualDevice.get_telemetry(:test_device_4)
      assert telemetry.counter == 0
    end

    test "handles unknown command" do
      assert {:error, :unknown_command} = VirtualDevice.send_command(:test_device_4, :invalid)
    end

    test "commands are recorded in device state" do
      VirtualDevice.send_command(:test_device_4, {:increment, 10})
      VirtualDevice.send_command(:test_device_4, :get_state)

      {:ok, commands} = VirtualDevice.send_command(:test_device_4, :get_commands)

      assert :get_state in commands
      assert {:increment, 10} in commands
    end
  end

  describe "periodic updates" do
    test "device publishes telemetry periodically" do
      opts = [
        device_id: "test_device_5",
        device_state_module: TestDevice,
        telemetry_aggregator_module: TestAggregator,
        schedule_ms: 50
      ]

      {:ok, pid} = VirtualDevice.start_link(opts)

      # Wait for several update cycles
      Process.sleep(200)

      telemetry_list = TestAggregator.get_telemetry()

      # Should have at least 3 updates
      assert length(telemetry_list) >= 3

      # Counter should increment with each update
      counters = Enum.map(telemetry_list, & &1.counter)
      assert counters == Enum.sort(counters)

      GenServer.stop(pid)
    end
  end
end
