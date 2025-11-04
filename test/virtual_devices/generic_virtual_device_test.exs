defmodule Pluribus.VirtualDevices.GenericVirtualDeviceTest do
  use ExUnit.Case, async: true

  alias Pluribus.VirtualDevices.GenericVirtualDevice

  describe "update_state/1" do
    test "increments count by 1" do
      {:ok, initial_state} = GenericVirtualDevice.init("test_device", initial_count: 5)

      assert {:ok, new_state} = GenericVirtualDevice.update_state(initial_state)

      assert new_state.count == 6
    end

    test "increments count multiple times" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 0)

      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 1

      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 2

      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 3
    end

    test "resets to 0 when exceeding max_count" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 10, max_count: 10)

      # Count is at 10, max is 10, next increment should reset
      assert {:ok, new_state} = GenericVirtualDevice.update_state(state)

      assert new_state.count == 0
      assert new_state.max_count == 10
    end

    test "does not reset when at max_count boundary" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 9, max_count: 10)

      # Count is at 9, max is 10, should increment to 10
      assert {:ok, new_state} = GenericVirtualDevice.update_state(state)

      assert new_state.count == 10
    end

    test "resets immediately after reaching max" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 99, max_count: 100)

      # Go from 99 to 100 (ok)
      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 100

      # Go from 100 to 0 (reset)
      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 0
    end

    test "preserves device_id and max_count during updates" do
      {:ok, state} = GenericVirtualDevice.init(:my_device, max_count: 50)

      {:ok, new_state} = GenericVirtualDevice.update_state(state)

      assert new_state.id == :my_device
      assert new_state.max_count == 50
    end
  end

  describe "report_telemetry/1" do
    test "returns telemetry with correct structure" do
      {:ok, state} = GenericVirtualDevice.init("test_device", [])

      telemetry = GenericVirtualDevice.report_telemetry(state)

      assert telemetry.device_id == "test_device"
      assert telemetry.device_type == "Counter"
      assert is_integer(telemetry.timestamp)
      assert is_map(telemetry.data)
    end

    test "includes current count in telemetry data" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 42)

      telemetry = GenericVirtualDevice.report_telemetry(state)

      assert telemetry.data.current_count == 42
    end

    test "includes count limit in telemetry data" do
      {:ok, state} = GenericVirtualDevice.init("test_device", max_count: 200)

      telemetry = GenericVirtualDevice.report_telemetry(state)

      assert telemetry.data.count_limit == 200
    end

    test "telemetry timestamp is in milliseconds" do
      {:ok, state} = GenericVirtualDevice.init("test_device", [])

      before = System.os_time(:millisecond)
      telemetry = GenericVirtualDevice.report_telemetry(state)
      after_time = System.os_time(:millisecond)

      assert telemetry.timestamp >= before
      assert telemetry.timestamp <= after_time
    end

    test "telemetry reflects updated state" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 5)
      {:ok, updated_state} = GenericVirtualDevice.update_state(state)

      telemetry = GenericVirtualDevice.report_telemetry(updated_state)

      assert telemetry.data.current_count == 6
    end

    test "telemetry after reset shows zero count" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 10, max_count: 10)
      {:ok, reset_state} = GenericVirtualDevice.update_state(state)

      telemetry = GenericVirtualDevice.report_telemetry(reset_state)

      assert telemetry.data.current_count == 0
    end
  end

  describe "handle_command/2 - set_max" do
    test "sets new max_count" do
      {:ok, state} = GenericVirtualDevice.init("test_device", max_count: 100)

      assert {:reply, {:ok, 200}, new_state} =
               GenericVirtualDevice.handle_command({:set_max, 200}, state)

      assert new_state.max_count == 200
    end

    test "returns the new max value in reply" do
      {:ok, state} = GenericVirtualDevice.init("test_device", [])

      assert {:reply, {:ok, 500}, _new_state} =
               GenericVirtualDevice.handle_command({:set_max, 500}, state)
    end

    test "preserves count when setting max" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 42)

      assert {:reply, {:ok, 200}, new_state} =
               GenericVirtualDevice.handle_command({:set_max, 200}, state)

      assert new_state.count == 42
    end

    test "preserves device_id when setting max" do
      {:ok, state} = GenericVirtualDevice.init(:my_device, [])

      assert {:reply, {:ok, 150}, new_state} =
               GenericVirtualDevice.handle_command({:set_max, 150}, state)

      assert new_state.id == :my_device
    end

    test "can set max lower than current count" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 80, max_count: 100)

      # Set max to 50, which is lower than current count (80)
      assert {:reply, {:ok, 50}, new_state} =
               GenericVirtualDevice.handle_command({:set_max, 50}, state)

      assert new_state.max_count == 50
      # Count unchanged
      assert new_state.count == 80

      # Next update should reset to 0
      {:ok, updated_state} = GenericVirtualDevice.update_state(new_state)
      assert updated_state.count == 0
    end

    test "rejects zero max_count" do
      {:ok, state} = GenericVirtualDevice.init("test_device", [])

      # Guard clause requires new_max > 0
      assert {:reply, {:error, :unknown_command}, _state} =
               GenericVirtualDevice.handle_command({:set_max, 0}, state)
    end

    test "rejects negative max_count" do
      {:ok, state} = GenericVirtualDevice.init("test_device", [])

      assert {:reply, {:error, :unknown_command}, _state} =
               GenericVirtualDevice.handle_command({:set_max, -10}, state)
    end

    test "rejects non-integer max_count" do
      {:ok, state} = GenericVirtualDevice.init("test_device", [])

      assert {:reply, {:error, :unknown_command}, _state} =
               GenericVirtualDevice.handle_command({:set_max, "100"}, state)

      assert {:reply, {:error, :unknown_command}, _state} =
               GenericVirtualDevice.handle_command({:set_max, 100.5}, state)
    end
  end

  describe "handle_command/2 - reset_count" do
    test "resets count to zero" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 42)

      assert {:reply, :reset_complete, new_state} =
               GenericVirtualDevice.handle_command({:reset_count}, state)

      assert new_state.count == 0
    end

    test "returns reset_complete reply" do
      {:ok, state} = GenericVirtualDevice.init("test_device", [])

      assert {:reply, :reset_complete, _new_state} =
               GenericVirtualDevice.handle_command({:reset_count}, state)
    end

    test "preserves max_count when resetting" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 50, max_count: 200)

      assert {:reply, :reset_complete, new_state} =
               GenericVirtualDevice.handle_command({:reset_count}, state)

      assert new_state.max_count == 200
    end

    test "preserves device_id when resetting" do
      {:ok, state} = GenericVirtualDevice.init(:my_device, initial_count: 30)

      assert {:reply, :reset_complete, new_state} =
               GenericVirtualDevice.handle_command({:reset_count}, state)

      assert new_state.id == :my_device
    end

    test "resetting already zero count is idempotent" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 0)

      assert {:reply, :reset_complete, new_state} =
               GenericVirtualDevice.handle_command({:reset_count}, state)

      assert new_state.count == 0
    end
  end

  describe "handle_command/2 - unknown commands" do
    test "returns error for unknown command atom" do
      {:ok, state} = GenericVirtualDevice.init("test_device", [])

      assert {:reply, {:error, :unknown_command}, returned_state} =
               GenericVirtualDevice.handle_command(:unknown, state)

      # State should be unchanged
      assert returned_state == state
    end

    test "returns error for unknown command tuple" do
      {:ok, state} = GenericVirtualDevice.init("test_device", [])

      assert {:reply, {:error, :unknown_command}, returned_state} =
               GenericVirtualDevice.handle_command({:invalid_command, 123}, state)

      assert returned_state == state
    end

    test "does not modify state on unknown command" do
      {:ok, state} = GenericVirtualDevice.init("test_device", initial_count: 25, max_count: 100)

      {:reply, {:error, :unknown_command}, new_state} =
        GenericVirtualDevice.handle_command(:bad_command, state)

      assert new_state.count == 25
      assert new_state.max_count == 100
      assert new_state.id == "test_device"
    end
  end

  describe "integration - full lifecycle" do
    test "device goes through typical lifecycle" do
      {:ok, state} = GenericVirtualDevice.init(:lifecycle_test, initial_count: 0, max_count: 5)
      assert state.count == 0

      # Update multiple times
      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 1

      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 2

      # Check telemetry
      telemetry = GenericVirtualDevice.report_telemetry(state)
      assert telemetry.data.current_count == 2

      # Send command to change max
      {:reply, {:ok, 3}, state} = GenericVirtualDevice.handle_command({:set_max, 3}, state)
      assert state.max_count == 3

      # Update to max
      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 3

      # Update past max (should reset)
      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 0

      # Verify telemetry after reset
      telemetry = GenericVirtualDevice.report_telemetry(state)
      assert telemetry.data.current_count == 0
      assert telemetry.data.count_limit == 3
    end

    test "device handles reset and continues counting" do
      {:ok, state} = GenericVirtualDevice.init(:reset_test, initial_count: 10)

      # Reset count
      {:reply, :reset_complete, state} =
        GenericVirtualDevice.handle_command({:reset_count}, state)

      assert state.count == 0

      # Continue counting
      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 1

      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 2

      # Telemetry shows correct count
      telemetry = GenericVirtualDevice.report_telemetry(state)
      assert telemetry.data.current_count == 2
    end

    test "device with low max_count cycles multiple times" do
      {:ok, state} = GenericVirtualDevice.init(:cycle_test, initial_count: 0, max_count: 2)

      # First cycle: 0 -> 1 -> 2 -> 0
      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 1

      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 2

      {:ok, state} = GenericVirtualDevice.update_state(state)
      # Reset
      assert state.count == 0

      # Second cycle: 0 -> 1 -> 2 -> 0
      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 1

      {:ok, state} = GenericVirtualDevice.update_state(state)
      assert state.count == 2

      {:ok, state} = GenericVirtualDevice.update_state(state)
      # Reset again
      assert state.count == 0
    end
  end
end
