defmodule Pluribus.TelemetryAggregators.ConsoleTelemetryAggregator do
  @moduledoc """
  Simple console aggregator implementation, logs each telemetry payload to console.
  """

  require Logger

  @behaviour Pluribus.TelemetryAggregator

  @impl true
  def publish_telemetry(telemetry) do
    Logger.info("Publishing telemetry #{inspect(telemetry)}")
    :ok
  end
end
