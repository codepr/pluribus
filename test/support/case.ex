defmodule Pluribus.TestCase do
  @moduledoc """
  Base test case module that provides common setup for all Pluribus tests.

  Use this in your tests like:
      use Pluribus.TestCase
  """

  use ExUnit.CaseTemplate

  alias Pluribus.TelemetryAggregators.TestAggregator

  using do
    quote do
      import Pluribus.TestHelpers
      import Pluribus.TestCase

      alias Pluribus.TelemetryAggregators.TestAggregator
      alias Pluribus.VirtualDevice
      alias Pluribus.VirtualDevices.TestDevice
    end
  end

  setup tags do
    # Clear any test telemetry before each test
    TestAggregator.clear_telemetry()

    # Track started devices for cleanup
    device_ids = []

    on_exit(fn ->
      # Cleanup: stop all devices started in the test
      cleanup_devices(tags[:devices] || [])
    end)

    {:ok, device_ids: device_ids}
  end

  defp cleanup_devices(device_ids) when is_list(device_ids) do
    Enum.each(device_ids, fn device_id ->
      case Pluribus.lookup_device(device_id) do
        {:ok, pid} ->
          try do
            GenServer.stop(pid, :normal, 1000)
          catch
            :exit, _ -> :ok
          end

        {:error, :not_found} ->
          :ok
      end
    end)
  end
end
