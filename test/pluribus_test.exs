defmodule PluribusTest do
  use ExUnit.Case, async: false

  import Pluribus.TestHelpers

  alias Pluribus.TelemetryAggregators.TestAggregator
  alias Pluribus.VirtualDevices.TestDevice

  setup do
    TestAggregator.clear_telemetry()
    :ok
  end

  describe "deploy_device/2" do
    test "deploys a device with default options" do
      assert {:ok, pid} = Pluribus.deploy_device(TestDevice, device_id: "api_test_1")
      assert Process.alive?(pid)
      assert :ok = wait_for_device("api_test_1")
    end

    test "deploys a device with custom aggregator" do
      opts = [
        device_id: "api_test_2",
        aggregator_module: TestAggregator
      ]

      assert {:ok, _pid} = Pluribus.deploy_device(TestDevice, opts)
      assert :ok = wait_for_device("api_test_2")
    end
  end

  describe "lookup_device/1" do
    test "finds deployed device" do
      {:ok, _} = Pluribus.deploy_device(TestDevice, device_id: "api_test_3")
      wait_for_device("api_test_3")

      assert {:ok, pid} = Pluribus.lookup_device("api_test_3")
      assert is_pid(pid)
    end

    test "returns error for non-existent device" do
      assert {:error, :not_found} = Pluribus.lookup_device("nonexistent")
    end
  end

  describe "deploy_fleet/1" do
    test "deploys multiple devices" do
      fleet_spec = [
        %{
          device_id: "api_fleet_1",
          state_module: TestDevice,
          telemetry_aggregator: TestAggregator
        },
        %{
          device_id: "api_fleet_2",
          state_module: TestDevice,
          telemetry_aggregator: TestAggregator
        },
        %{
          device_id: "api_fleet_3",
          state_module: TestDevice,
          telemetry_aggregator: TestAggregator
        }
      ]

      results = Pluribus.deploy_fleet(fleet_spec)

      assert length(results) == 3
      assert Enum.all?(results, fn {:ok, _} -> true end)

      wait_for_device("api_fleet_1")
      wait_for_device("api_fleet_2")
      wait_for_device("api_fleet_3")

      assert {:ok, _} = Pluribus.lookup_device("api_fleet_1")
      assert {:ok, _} = Pluribus.lookup_device("api_fleet_2")
      assert {:ok, _} = Pluribus.lookup_device("api_fleet_3")
    end
  end

  describe "fleet_count/0" do
    test "returns fleet statistics" do
      counts = Pluribus.fleet_count()

      assert is_map(counts)
      assert is_integer(counts.specs)
      assert is_integer(counts.active)
      assert is_integer(counts.supervisors)
      assert is_integer(counts.workers)
    end
  end

  describe "integration: full workflow" do
    test "deploy, lookup, command, and telemetry" do
      {:ok, _pid} =
        Pluribus.deploy_device(
          TestDevice,
          device_id: "integration_test",
          aggregator_module: TestAggregator,
          schedule_ms: 100
        )

      wait_for_device("integration_test")

      assert {:ok, device_pid} = Pluribus.lookup_device("integration_test")
      assert Process.alive?(device_pid)

      assert {:ok, _} = Pluribus.send_command("integration_test", {:increment, 5})

      telemetry = Pluribus.get_telemetry("integration_test")
      assert telemetry.device_id == "integration_test"

      # Wait for periodic updates
      Process.sleep(250)

      # Check aggregated telemetry
      aggregated = TestAggregator.get_telemetry()
      assert length(aggregated) >= 2
    end
  end
end
