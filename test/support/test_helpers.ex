defmodule Pluribus.TestHelpers do
  @moduledoc """
  Helper functions for Pluribus tests
  """

  def wait_for_device(device_id, timeout \\ 1000) do
    wait_until(
      fn ->
        case Pluribus.lookup_device(device_id) do
          {:ok, _pid} -> true
          _ -> false
        end
      end,
      timeout
    )
  end

  def wait_until(fun, timeout \\ 1000) do
    end_time = System.monotonic_time(:millisecond) + timeout
    do_wait_until(fun, end_time)
  end

  defp do_wait_until(fun, end_time) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) < end_time do
        Process.sleep(10)
        do_wait_until(fun, end_time)
      else
        {:error, :timeout}
      end
    end
  end
end
