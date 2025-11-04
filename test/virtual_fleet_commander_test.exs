defmodule Pluribus.VirtualFleetCommanderTest do
  use ExUnit.Case, async: false

  import Pluribus.TestHelpers

  alias Pluribus.TelemetryAggregators.TestAggregator
  alias Pluribus.VirtualDevices.TestDevice
  alias Pluribus.VirtualFleetCommander

  setup do
    TestAggregator.clear_telemetry()
    :ok
  end

  describe "start_device/3" do
    test "starts a single device in the cluster" do
      opts = [device_id: "fleet_test_1"]

      assert {:ok, pid} =
               VirtualFleetCommander.start_device(
                 TestDevice,
                 TestAggregator,
                 opts
               )

      assert Process.alive?(pid)
      assert :ok = wait_for_device("fleet_test_1")
    end

    test "generates device_id if not provided" do
      assert {:ok, _pid} =
               VirtualFleetCommander.start_device(
                 TestDevice,
                 TestAggregator,
                 []
               )
    end
  end

  describe "lookup_device/1" do
    test "finds an existing device" do
      opts = [device_id: "fleet_test_3"]
      {:ok, original_pid} = VirtualFleetCommander.start_device(TestDevice, TestAggregator, opts)

      assert :ok = wait_for_device("fleet_test_3")
      assert {:ok, ^original_pid} = VirtualFleetCommander.lookup_device("fleet_test_3")
    end

    test "returns error for non-existent device" do
      assert {:error, :not_found} = VirtualFleetCommander.lookup_device(:does_not_exist)
    end
  end

  describe "start_fleet/1" do
    test "starts multiple devices" do
      devices_spec = [
        %{device_id: "fleet_1", state_module: TestDevice, telemetry_aggregator: TestAggregator},
        %{device_id: "fleet_2", state_module: TestDevice, telemetry_aggregator: TestAggregator},
        %{device_id: "fleet_3", state_module: TestDevice, telemetry_aggregator: TestAggregator}
      ]

      results = VirtualFleetCommander.start_fleet(devices_spec)

      assert length(results) == 3

      assert Enum.all?(results, fn
               {:ok, pid} when is_pid(pid) -> true
               _ -> false
             end)

      assert :ok = wait_for_device("fleet_1")
      assert :ok = wait_for_device("fleet_2")
      assert :ok = wait_for_device("fleet_3")
    end

    test "handles devices with minimal spec" do
      devices_spec = [
        %{device_id: "minimal_1"},
        %{device_id: "minimal_2"}
      ]

      results = VirtualFleetCommander.start_fleet(devices_spec)

      assert length(results) == 2
      assert Enum.all?(results, fn {:ok, _} -> true end)
    end

    test "starts empty fleet" do
      assert [] = VirtualFleetCommander.start_fleet([])
    end
  end

  describe "fleet_count/0" do
    test "returns count structure" do
      devices_spec = [
        %{device_id: "count_1", state_module: TestDevice, telemetry_aggregator: TestAggregator},
        %{device_id: "count_2", state_module: TestDevice, telemetry_aggregator: TestAggregator}
      ]

      VirtualFleetCommander.start_fleet(devices_spec)
      wait_for_device("count_1")
      wait_for_device("count_2")

      counts = VirtualFleetCommander.fleet_count()

      assert is_map(counts)
      assert Map.has_key?(counts, :specs)
      assert Map.has_key?(counts, :active)
      assert Map.has_key?(counts, :supervisors)
      assert Map.has_key?(counts, :workers)
    end
  end
end
