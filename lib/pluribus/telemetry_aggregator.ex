defmodule Pluribus.TelemetryAggregator do
  @moduledoc """
  Defines the required behavior for a telemetry aggregation module, can be an MQTT
  client, or a Phoenix PubSub, Kafka client etc.

  Any module implementing this behavior is responsible for defining a publish logic
  in order to be plugged-in in a VirtualDevice.
  """

  @callback publish_telemetry(telemetry :: term()) :: :ok | {:error, map()}
end
