defmodule Pluribus.VirtualDeviceState do
  @moduledoc """
  Defines the required behavior for a device's specific state and actions.

  Any module implementing this behavior is responsible for managing the device's
  internal state, processing commands, and generating telemetry reports.
  """

  @callback init(device_id :: term(), opts :: Keyword.t()) :: {:ok, state :: map()}
  @callback update_state(state :: map()) :: {:ok, new_state :: map()}
  @callback report_telemetry(state :: map()) :: map()
  @callback handle_command(command :: atom(), state :: map()) ::
              {:noreply, map()} | {:reply, term(), map()}
end
