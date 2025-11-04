defmodule Pluribus.TelemetryAggregators.ConsoleTelemetryAggregatorTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Pluribus.TelemetryAggregators.ConsoleTelemetryAggregator

  describe "publish_telemetry/1" do
    test "logs telemetry payload to console" do
      telemetry_payload = inspect(%{count: 10, topic: "any_topic"})

      assert capture_log(fn ->
               assert :ok == ConsoleTelemetryAggregator.publish_telemetry(telemetry_payload)
             end) =~ "[info] Publishing telemetry"
    end
  end
end
